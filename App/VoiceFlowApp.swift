/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 AppState 全局状态
 * [OUTPUT]: 对外提供 @main App 入口点
 * [POS]: VoiceFlow 应用的根入口，管理 MenuBarExtra 生命周期
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI
import SwiftData

// ========================================
// MARK: - VoiceFlow App
// ========================================

@main
struct VoiceFlowApp: App {

    @State private var appState = AppState.shared

    init() {
        // 在初始化时设置 HotkeyMonitor
        VoiceFlowApp.setupHotkeyMonitor()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("退出 VoiceFlow") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }

    // ----------------------------------------
    // MARK: - Hotkey Setup
    // ----------------------------------------

    private static func setupHotkeyMonitor() {
        Task { @MainActor in
            // 加载保存的快捷键配置
            AppState.shared.loadSavedConfig()

            // 设置 HotkeyMonitor 配置
            HotkeyMonitor.shared.updateConfig(AppState.shared.hotkeyConfig)

            HotkeyMonitor.shared.onStartRecording = {
                Task { @MainActor in
                    print("[VoiceFlowApp] Start recording triggered")
                    AppState.shared.currentStatus = .recording
                    AppState.shared.startNewSession()
                    // 启动完整录音流程（会自动显示录音指示器）
                    RecordingCoordinator.shared.startRecording()
                }
            }

            HotkeyMonitor.shared.onStopRecording = {
                Task { @MainActor in
                    print("[VoiceFlowApp] Stop recording triggered")
                    // 停止录音并触发 LLM 润色 + 注入
                    // 指示器状态由 RecordingCoordinator 管理
                    RecordingCoordinator.shared.stopRecording()
                }
            }

            HotkeyMonitor.shared.onCancelRecording = {
                Task { @MainActor in
                    print("[VoiceFlowApp] Cancel recording triggered")
                    // 隐藏录音指示器
                    RecordingIndicatorManager.shared.hide()
                    // 取消录音并清理所有状态
                    RecordingCoordinator.shared.cancelRecording()
                }
            }

            // 启动监听
            let success = HotkeyMonitor.shared.startMonitoring()
            print("[VoiceFlowApp] HotkeyMonitor started: \(success)")
        }
    }

    // ----------------------------------------
    // MARK: - Menu Bar Icon
    // ----------------------------------------

    private var menuBarIcon: String {
        switch appState.currentStatus {
        case .idle:
            return "waveform.circle"
        case .recording:
            return "waveform.circle.fill"
        case .processing:
            return "waveform.circle.badge.spinner"
        case .injecting:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
}
