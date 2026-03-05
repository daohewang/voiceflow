/**
 * [INPUT]: 依赖 Foundation URLSessionWebSocketTask，依赖 AudioEngine
 * [OUTPUT]: 对外提供 ASRClient 类，WebSocket 连接管理 + 实时转录回调
 * [POS]: VoiceFlow/Core 的语音识别层，消费 AudioEngine 数据，被 AppState 调用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation

// ========================================
// MARK: - ASR Client
// ========================================

/// ElevenLabs Scribe v2 WebSocket ASR 客户端
/// 职责：WebSocket 连接管理、音频流上传、实时转录结果回调
final class ASRClient: @unchecked Sendable {

    // ----------------------------------------
    // MARK: - Configuration
    // ----------------------------------------

    private let apiKey: String

    // ----------------------------------------
    // MARK: - Reconnection
    // ----------------------------------------

    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0  // 1s → 2s → 4s
    private var retryCount = 0
    private var isManuallyDisconnected = false  // 防止 disconnect() 后触发重连

    // ----------------------------------------
    // MARK: - WebSocket
    // ----------------------------------------

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    private(set) var isConnected = false
    private var isReconnecting = false

    // ----------------------------------------
    // MARK: - Callbacks
    // ----------------------------------------

    /// 转录结果回调
    var onTranscription: ((String, Bool) -> Void)?  // (text, isFinal)

    /// 连接状态变化回调
    var onConnectionStateChange: ((Bool) -> Void)?

    /// 错误回调
    var onError: ((Error) -> Void)?

    // ----------------------------------------
    // MARK: - Lifecycle
    // ----------------------------------------

    init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }

    deinit {
        disconnect()
    }

    // ----------------------------------------
    // MARK: - Connection Management
    // ----------------------------------------

    /// 连接到 ASR 服务
    func connect() async throws {
        guard !isConnected else { return }

        // xi-api-key 只支持 Header 鉴权，query param 只支持 token（单次令牌）
        isManuallyDisconnected = false
        let url = URL(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime?model_id=scribe_v2_realtime")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // 等待连接建立
        try await waitForConnection()

        isConnected = true
        retryCount = 0
        onConnectionStateChange?(true)

        // 开始监听消息
        listenForMessages()

        print("[ASRClient] Connected to ElevenLabs Scribe v2")
    }

    private func waitForConnection() async throws {
        // 等待一小段时间让连接建立
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    /// 断开连接
    func disconnect() {
        isManuallyDisconnected = true  // 阻止 listenForMessages failure 触发重连
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        onConnectionStateChange?(false)

        print("[ASRClient] Disconnected")
    }

    // ----------------------------------------
    // MARK: - Reconnection
    // ----------------------------------------

    private func reconnect() async {
        guard !isManuallyDisconnected && !isReconnecting && retryCount < maxRetries else {
            if !isManuallyDisconnected {
                onError?(ASRError.maxRetriesExceeded)
            }
            return
        }

        isReconnecting = true
        defer { isReconnecting = false }

        let delay = baseDelay * pow(2.0, Double(retryCount))
        retryCount += 1

        print("[ASRClient] Reconnecting in \(delay)s (attempt \(retryCount)/\(maxRetries))")

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
            try await connect()
        } catch {
            print("[ASRClient] Reconnection failed: \(error)")
            await reconnect()
        }
    }

    // ----------------------------------------
    // MARK: - Audio Streaming
    // ----------------------------------------

    /// 提交当前缓冲区，强制服务器输出最后一段 committed_transcript
    func commit() {
        guard isConnected, let task = webSocketTask else { return }

        let payload: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": "",
            "commit": true,
            "sample_rate": 16000
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        task.send(.string(jsonString)) { _ in }
        print("[ASRClient] Commit sent")
    }

    /// 发送音频数据 (必须用 JSON + base64，不能直接发 binary)
    func sendAudioData(_ data: Data) {
        guard isConnected, let task = webSocketTask else { return }

        let payload: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": data.base64EncodedString(),
            "commit": false,
            "sample_rate": 16000
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        task.send(.string(jsonString)) { error in
            if let error = error {
                print("[ASRClient] Send error: \(error)")
            }
        }
    }

    // ----------------------------------------
    // MARK: - Message Handling
    // ----------------------------------------

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // 继续监听
                self.listenForMessages()

            case .failure(let error):
                print("[ASRClient] Receive error: \(error)")
                self.isConnected = false
                self.onConnectionStateChange?(false)

                // 触发重连
                Task {
                    await self.reconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            parseTranscriptionResponse(data)

        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            parseTranscriptionResponse(data)

        @unknown default:
            break
        }
    }

    private func parseTranscriptionResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["message_type"] as? String else { return }

        // ElevenLabs Realtime STT 响应格式：
        // partial_transcript   → 中间结果，isFinal = false
        // committed_transcript → 最终结果，isFinal = true
        switch messageType {
        case "partial_transcript":
            guard let text = json["text"] as? String else { return }
            onTranscription?(text, false)

        case "committed_transcript":
            guard let text = json["text"] as? String else { return }
            onTranscription?(text, true)

        case "session_started":
            print("[ASRClient] Session started: \(json["session_id"] ?? "unknown")")

        case "auth_error":
            // API key 无效或无 Realtime STT 权限，停止重连
            print("[ASRClient] Auth error - check API key and Realtime STT subscription")
            isManuallyDisconnected = true
            onError?(ASRError.unauthorized)
            disconnect()

        default:
            print("[ASRClient] Unknown message_type: \(messageType)")
        }
    }
}

// ========================================
// MARK: - Error Types
// ========================================

enum ASRError: LocalizedError {
    case connectionFailed
    case maxRetriesExceeded
    case invalidResponse
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to ASR service"
        case .maxRetriesExceeded:
            return "Max reconnection attempts exceeded"
        case .invalidResponse:
            return "Invalid response from ASR service"
        case .unauthorized:
            return "Invalid API key"
        }
    }
}
