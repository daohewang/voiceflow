/**
 * [INPUT]: 依赖 Foundation (UserDefaults)
 * [OUTPUT]: 对外提供 KeychainManager 单例，存取 API Key
 * [POS]: VoiceFlow/Core 的存储层，被 AppState 和 SettingsView 消费
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 *
 * Note: 使用 UserDefaults 而非 Keychain，避免每次构建签名变化后需要重新授权密码
 */

import Foundation

// ========================================
// MARK: - Keychain Manager (UserDefaults-based)
// ========================================

/// API Key 存储管理器
/// 职责：API Key 的持久化存储
@MainActor
final class KeychainManager {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = KeychainManager()

    private let defaults = UserDefaults.standard
    private let prefix = "com.voiceflow."

    private init() {}

    // ----------------------------------------
    // MARK: - Keys
    // ----------------------------------------

    enum Key: String, Sendable, CaseIterable {
        case elevenLabs = "api.elevenlabs"
        case openRouter = "api.openrouter"
        // 新增 LLM 提供商
        case deepSeek = "api.deepseek"
        case miniMax = "api.minimax"
        case zhiPu = "api.zhipu"
        case kimi = "api.kimi"
        // 新增 ASR 提供商
        case openAI = "api.openai"
    }

    // ----------------------------------------
    // MARK: - CRUD Operations
    // ----------------------------------------

    /// 存储 API Key
    func set(_ value: String, for key: Key) throws {
        defaults.set(value, forKey: prefix + key.rawValue)
        defaults.synchronize()
    }

    /// 读取 API Key
    func get(_ key: Key) throws -> String? {
        let value = defaults.string(forKey: prefix + key.rawValue)
        return value?.isEmpty == false ? value : nil
    }

    /// 删除 API Key
    func delete(_ key: Key) throws {
        defaults.removeObject(forKey: prefix + key.rawValue)
        defaults.synchronize()
    }

    /// 更新 API Key
    func update(_ value: String, for key: Key) throws {
        try set(value, for: key)
    }

    /// 检查 Key 是否存在
    func exists(_ key: Key) -> Bool {
        guard let value = defaults.string(forKey: prefix + key.rawValue) else { return false }
        return !value.isEmpty
    }
}

// ========================================
// MARK: - Error Types (kept for compatibility)
// ========================================

enum KeychainError: LocalizedError, Sendable {
    case writeFailed(Int)
    case readFailed(Int)
    case deleteFailed(Int)
    case updateFailed(Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .writeFailed(let status):
            return "Storage write failed with status: \(status)"
        case .readFailed(let status):
            return "Storage read failed with status: \(status)"
        case .deleteFailed(let status):
            return "Storage delete failed with status: \(status)"
        case .updateFailed(let status):
            return "Storage update failed with status: \(status)"
        case .invalidData:
            return "Storage data is invalid"
        }
    }
}
