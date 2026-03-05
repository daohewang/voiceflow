/**
 * [INPUT]: 依赖 Security.framework 的 SecItem API
 * [OUTPUT]: 对外提供 KeychainManager 单例，安全存取 API Key
 * [POS]: VoiceFlow/Core 的安全层，被 AppState 和 SettingsView 消费
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation
import Security

// ========================================
// MARK: - Keychain Manager
// ========================================

/// Keychain 安全存储管理器
/// 职责：API Key 的加密持久化，读写原子性保证
final class KeychainManager: Sendable {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = KeychainManager()

    private init() {}

    // ----------------------------------------
    // MARK: - Service Identifier
    // ----------------------------------------

    private let service = "com.voiceflow.app"

    // ----------------------------------------
    // MARK: - Keys
    // ----------------------------------------

    enum Key: String, Sendable {
        case elevenLabs = "api.elevenlabs"
        case openRouter = "api.openrouter"
    }

    // ----------------------------------------
    // MARK: - CRUD Operations
    // ----------------------------------------

    /// 存储 API Key
    func set(_ value: String, for key: Key) throws {
        // 先尝试删除旧值（避免重复插入错误）
        try? delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: value.data(using: .utf8)!
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status)
        }
    }

    /// 读取 API Key
    func get(_ key: Key) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    /// 删除 API Key
    func delete(_ key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // ----------------------------------------
    // MARK: - Convenience API
    // ----------------------------------------

    /// 安全更新 API Key（存在则更新，不存在则创建）
    func update(_ value: String, for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: value.data(using: .utf8)!
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // 不存在，创建新条目
            try set(value, for: key)
        } else if status != errSecSuccess {
            throw KeychainError.updateFailed(status)
        }
    }

    /// 检查 Key 是否存在
    func exists(_ key: Key) -> Bool {
        do {
            return try get(key) != nil
        } catch {
            return false
        }
    }
}

// ========================================
// MARK: - Error Types
// ========================================

enum KeychainError: LocalizedError, Sendable {
    case writeFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case updateFailed(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .writeFailed(let status):
            return "Keychain write failed with status: \(status)"
        case .readFailed(let status):
            return "Keychain read failed with status: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status: \(status)"
        case .updateFailed(let status):
            return "Keychain update failed with status: \(status)"
        case .invalidData:
            return "Keychain data is invalid or corrupted"
        }
    }
}
