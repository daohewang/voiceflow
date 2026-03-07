/**
 * [INPUT]: 依赖 Foundation 框架
 * [OUTPUT]: 对外提供 ASRProvider 协议、ASRProviderType 枚举
 * [POS]: VoiceFlow 的 ASR 提供商抽象层，支持多提供商切换
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation

// ========================================
// MARK: - ASR Provider Types
// ========================================

enum ASRProviderType: String, Codable, CaseIterable, Identifiable {
    case elevenLabs = "ElevenLabs"
    case deepSeek = "DeepSeek"
    case openAI = "OpenAI"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var apiKeyName: String {
        switch self {
        case .elevenLabs: return "ElevenLabs API Key"
        case .deepSeek: return "DeepSeek API Key"
        case .openAI: return "OpenAI API Key"
        }
    }

    var keychainKey: KeychainManager.Key {
        switch self {
        case .elevenLabs: return .elevenLabs
        case .deepSeek: return .deepSeek
        case .openAI: return .openAI
        }
    }
}

// ========================================
// MARK: - ASR Provider Protocol
// ========================================

/// ASR 提供商协议 - 所有 ASR 实现必须遵循
protocol ASRProvider: Sendable {
    var type: ASRProviderType { get }
    var name: String { get }

    /// 连接到 ASR 服务
    func connect(apiKey: String) async throws

    /// 发送音频数据
    func sendAudioData(_ data: Data)

    /// 提交当前音频段（触发识别）
    func commit()

    /// 断开连接
    func disconnect()

    /// 是否已连接
    var isConnected: Bool { get }
}

// ========================================
// MARK: - ASR Callbacks
// ========================================

/// ASR 回调协议
protocol ASRProviderDelegate: AnyObject {
    /// 收到部分识别结果
    func asrProvider(_ provider: ASRProvider, didReceivePartialTranscript text: String)

    /// 收到最终识别结果
    func asrProvider(_ provider: ASRProvider, didReceiveFinalTranscript text: String)

    /// 发生错误
    func asrProvider(_ provider: ASRProvider, didFailWithError error: Error)

    /// 连接状态变化
    func asrProvider(_ provider: ASRProvider, didChangeConnectionState isConnected: Bool)
}

// ========================================
// MARK: - ASR Error
// ========================================

enum ASRProviderError: LocalizedError {
    case missingAPIKey
    case connectionFailed(String)
    case disconnected
    case audioEncodingFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未配置 API Key"
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .disconnected:
            return "未连接"
        case .audioEncodingFailed:
            return "音频编码失败"
        case .apiError(let message):
            return "API 错误: \(message)"
        }
    }
}
