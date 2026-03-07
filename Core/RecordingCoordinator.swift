/**
 * [INPUT]: 依赖 AudioEngine, ASRClient, LLMClient, TextInjector, AppState, KeychainManager
 * [OUTPUT]: 对外提供 RecordingCoordinator 单例，编排完整的录音→转录→润色→注入流程
 * [POS]: VoiceFlow 的数据流中枢，被 VoiceFlowApp 的快捷键回调调用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation

// ========================================
// MARK: - Recording Coordinator
// ========================================

/// 录音流程协调器
/// 职责：串联 AudioEngine → ASRClient → LLMClient → TextInjector 的完整数据流
@MainActor
@Observable
final class RecordingCoordinator {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = RecordingCoordinator()

    // ----------------------------------------
    // MARK: - Components
    // ----------------------------------------

    private var audioEngine: AudioEngine?
    private var asrClient: ASRClient?

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    private(set) var isRecording: Bool = false
    private var accumulatedASRText: String = ""
    private var currentSessionId: UUID = UUID()
    private var recordingStartTime: Date?

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private init() {}

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 开始录音流程
    func startRecording() {
        guard !isRecording else {
            print("[RecordingCoordinator] Already recording, ignoring start request")
            return
        }

        let appState = AppState.shared
        let sessionId = appState.currentSessionId

        // 1. 验证 API Key
        guard let elevenLabsKey = getAPIKey(.elevenLabs) else {
            appState.setError("请先在设置中配置 ElevenLabs API Key")
            print("[RecordingCoordinator] Missing ElevenLabs API Key")
            return
        }

        isRecording = true
        accumulatedASRText = ""
        currentSessionId = sessionId
        recordingStartTime = Date()

        print("[RecordingCoordinator] Starting recording session: \(sessionId)")

        // 2. 创建并连接组件
        let engine = AudioEngine()
        let asr = ASRClient(apiKey: elevenLabsKey)

        self.audioEngine = engine
        self.asrClient = asr

        // 3. 设置 ASR 回调
        asr.onTranscription = { [weak self] text, isFinal in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard AppState.shared.isValidSession(sessionId) else { return }

                if isFinal {
                    // Final 结果：追加到累积文本
                    if !self.accumulatedASRText.isEmpty {
                        self.accumulatedASRText += " "
                    }
                    self.accumulatedASRText += text
                    AppState.shared.asrText = self.accumulatedASRText
                    print("[RecordingCoordinator] ASR final: \(text)")
                } else {
                    // Partial 结果：显示累积文本 + 当前 partial
                    let display = self.accumulatedASRText.isEmpty
                        ? text
                        : self.accumulatedASRText + " " + text
                    AppState.shared.asrText = display
                }
            }
        }

        asr.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard AppState.shared.isValidSession(sessionId) else { return }
                print("[RecordingCoordinator] ASR error: \(error.localizedDescription)")
                // 错误时停止录音并清理，否则 AudioEngine 会一直采集
                self.audioEngine?.stopRecording()
                self.isRecording = false
                self.cleanup()
                RecordingIndicatorManager.shared.hide()
                AppState.shared.setError("语音识别错误: \(error.localizedDescription)")
            }
        }

        // 4. 连接 AudioEngine → ASRClient
        engine.onAudioData = { [weak asr] data in
            asr?.sendAudioData(data)
        }

        // 4.1 连接音量回调 → 指示器
        engine.onAudioLevel = { level in
            Task { @MainActor in
                RecordingIndicatorManager.shared.updateAudioLevel(level)
            }
        }

        // 5. 启动 ASR 连接 + 音频引擎 + 显示指示器
        Task {
            do {
                try await asr.connect()
                print("[RecordingCoordinator] ASR connected")

                try engine.startRecording()
                print("[RecordingCoordinator] AudioEngine started")

                // 显示录音指示器
                RecordingIndicatorManager.shared.showRecording()
            } catch {
                print("[RecordingCoordinator] Start failed: \(error.localizedDescription)")
                AppState.shared.setError("启动录音失败: \(error.localizedDescription)")
                self.isRecording = false
                self.cleanup()
            }
        }
    }

    /// 停止录音并触发 LLM 润色 + 文本注入
    func stopRecording() {
        guard isRecording else {
            print("[RecordingCoordinator] Not recording, ignoring stop request")
            return
        }

        let sessionId = currentSessionId

        // 计算录音时长
        var recordingDuration: TimeInterval = 0
        if let startTime = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
        recordingStartTime = nil

        // 1. 立即停止音频采集
        audioEngine?.stopRecording()
        isRecording = false

        // 1.1 切换到处理状态 UI
        AppState.shared.currentStatus = .processing
        RecordingIndicatorManager.shared.showProcessing()

        // 2. commit → 等服务器返回最后一段 committed_transcript → 断连 → 处理文本
        let asr = asrClient
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 发 commit 信号，强制服务器输出缓冲区里的最后一段语音
            asr?.commit()

            // 等待最多 1.5s，让 committed_transcript 回来
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            asr?.disconnect()

            print("[RecordingCoordinator] Stopping recording, committed: '\(self.accumulatedASRText)', partial: '\(AppState.shared.asrText)'")

            // committed 文本优先；无 committed 则用 partial (asrText) 兜底
            let finalText = (self.accumulatedASRText.isEmpty
                ? AppState.shared.asrText
                : self.accumulatedASRText
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !finalText.isEmpty else {
                print("[RecordingCoordinator] No ASR text, returning to idle")
                AppState.shared.currentStatus = .idle
                RecordingIndicatorManager.shared.hide()
                self.cleanup()
                return
            }

            guard AppState.shared.isValidSession(sessionId) else {
                print("[RecordingCoordinator] Invalid session, aborting")
                RecordingIndicatorManager.shared.hide()
                self.cleanup()
                return
            }

            // 捕获录音时长（在 Task 外部计算的局部变量）
            let durationSecs = Int(recordingDuration)

            // 获取用户选择的 LLM 提供商和对应的 API Key
            let llmProvider = AppState.shared.llmProvider
            let llmKey: String? = self.getAPIKey(llmProvider.keychainKey)

            // 无 LLM Key → 直接注入原始文本
            guard let apiKey = llmKey, !apiKey.isEmpty else {
                print("[RecordingCoordinator] No \(llmProvider.displayName) key, injecting raw ASR text")
                self.injectText(finalText, asrText: finalText, sessionId: sessionId, durationSeconds: durationSecs)
                return
            }

            // 有 LLM Key → 润色后注入
            let llmClient = LLMClient.shared
            let styleId = AppState.shared.selectedStyleId

            llmClient.onTextUpdate = { updatedText in
                Task { @MainActor in
                    guard AppState.shared.isValidSession(sessionId) else { return }
                    AppState.shared.llmText = updatedText
                }
            }

            llmClient.onComplete = { [weak self] completedText in
                Task { @MainActor [weak self] in
                    guard AppState.shared.isValidSession(sessionId) else { return }
                    print("[RecordingCoordinator] LLM complete: \(completedText)")
                    self?.injectText(completedText, asrText: finalText, sessionId: sessionId, durationSeconds: durationSecs)
                }
            }

            llmClient.onError = { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    guard AppState.shared.isValidSession(sessionId) else { return }
                    print("[RecordingCoordinator] LLM error: \(error.localizedDescription), injecting raw ASR text")
                    self.injectText(finalText, asrText: finalText, sessionId: sessionId, durationSeconds: durationSecs)
                }
            }

            print("[RecordingCoordinator] Starting LLM polish with \(llmProvider.displayName) for: '\(finalText)'")
            llmClient.polishText(finalText, style: styleId, apiKey: apiKey, providerType: llmProvider)

            // 35秒超时保护（LLM超时30秒 + 5秒缓冲）
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 35_000_000_000)
                guard AppState.shared.isValidSession(sessionId) else { return }
                if AppState.shared.currentStatus == .processing {
                    print("[RecordingCoordinator] LLM timeout, injecting raw ASR text")
                    llmClient.cancel()
                    self?.injectText(finalText, asrText: finalText, sessionId: sessionId, durationSeconds: durationSecs)
                }
            }
        }
    }

    /// 取消录音
    func cancelRecording() {
        print("[RecordingCoordinator] Cancelling recording")

        audioEngine?.stopRecording()
        asrClient?.disconnect()
        LLMClient.shared.cancel()

        isRecording = false
        accumulatedASRText = ""

        let appState = AppState.shared
        appState.currentStatus = .idle
        appState.asrText = ""
        appState.llmText = ""

        RecordingIndicatorManager.shared.hide()
        cleanup()
    }

    // ----------------------------------------
    // MARK: - Private Helpers
    // ----------------------------------------

    /// 注入文本到当前输入框
    private func injectText(_ text: String, asrText: String, sessionId: UUID, durationSeconds: Int) {
        let appState = AppState.shared
        guard appState.isValidSession(sessionId) else {
            print("[RecordingCoordinator] Invalid session, skipping inject")
            return
        }

        print("[RecordingCoordinator] Injecting text: '\(text)'")

        // 主动请求辅助功能权限（会弹出系统对话框或打开系统设置）
        let granted = PermissionManager.shared.requestAccessibilityPermission()
        print("[RecordingCoordinator] Accessibility permission result: \(granted)")

        guard granted else {
            print("[RecordingCoordinator] Accessibility permission not granted, opening system preferences")
            // 打开系统设置让用户授权
            PermissionManager.shared.openAccessibilityPreferences()
            RecordingIndicatorManager.shared.hide()
            appState.setError("请在系统设置中添加 VoiceFlow 到辅助功能列表，然后重试录音。")
            return
        }

        appState.currentStatus = .injecting

        let injector = TextInjector.shared

        injector.onInjectComplete = {
            Task { @MainActor in
                guard AppState.shared.isValidSession(sessionId) else { return }
                print("[RecordingCoordinator] Text injected successfully")
                AppState.shared.currentStatus = .idle

                // 更新统计数据（传入真实录音时长）
                let charCount = text.count
                UsageStats.shared.recordSession(durationSeconds: max(1, durationSeconds), characterCount: charCount)

                // 保存历史条目
                AppState.shared.addHistoryEntry(
                    asrText: asrText,
                    finalText: text,
                    durationSeconds: durationSeconds
                )

                // 隐藏指示器
                RecordingIndicatorManager.shared.hide()

                // 1.5 秒后清除显示文本
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if AppState.shared.isValidSession(sessionId) {
                    AppState.shared.asrText = ""
                    AppState.shared.llmText = ""
                }
            }
        }

        injector.onInjectError = { error in
            Task { @MainActor in
                guard AppState.shared.isValidSession(sessionId) else { return }
                print("[RecordingCoordinator] Inject error: \(error.localizedDescription)")
                // 隐藏指示器
                RecordingIndicatorManager.shared.hide()
                AppState.shared.setError("文本注入失败: \(error.localizedDescription)")
            }
        }

        injector.injectText(text)
    }

    /// 从 Keychain 获取 API Key
    private func getAPIKey(_ key: KeychainManager.Key) -> String? {
        guard let value = try? KeychainManager.shared.get(key),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    /// 清理资源
    private func cleanup() {
        audioEngine = nil
        asrClient = nil
    }
}
