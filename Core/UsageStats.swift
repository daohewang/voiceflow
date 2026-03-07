/**
 * [INPUT]: 无外部依赖， * [OUTPUT]: 对外提供 UsageStats 单例，使用统计数据管理
 * [POS]: VoiceFlow/Core 的统计层，被 AppState 和 MainWindow 消费
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation

// ========================================
// MARK: - Usage Stats
// ========================================

@MainActor
@Observable
final class UsageStats {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = UsageStats()

    // ----------------------------------------
    // MARK: - Properties
    // ----------------------------------------

    /// 总录音次数
    private(set) var totalRecordings: Int = 0

    /// 总录音时长（秒）
    private(set) var totalRecordingSeconds: Int = 0

    /// 总输入字数
    private(set) var totalCharactersTyped: Int = 0

    /// 估算节省时间（分钟）
    var savedMinutes: Int {
        // 假设平均打字速度 60 字/分钟，说话速度 150 字/分钟
        // 节省时间 = (字数 / 60) - (字数 / 150) = 字数 * (1/60 - 1/150) ≈ 字数 * 0.015
        return Int(Double(totalCharactersTyped) * 0.015)
    }

    /// 格式化的录音时间显示
    var formattedRecordingTime: String {
        let minutes = totalRecordingSeconds / 60
        let seconds = totalRecordingSeconds % 60
        if minutes > 0 {
            return "\(minutes) 分钟"
        }
        return "\(seconds) 秒"
    }

    /// 格式化的节省时间显示
    var formattedTimeSaved: String {
        return "\(savedMinutes) 分钟"
    }

    // ----------------------------------------
    // MARK: - Storage Keys
    // ----------------------------------------

    private let defaults = UserDefaults.standard
    private enum Key: String {
        case totalRecordings = "usage.totalRecordings"
        case totalRecordingSeconds = "usage.totalRecordingSeconds"
        case totalCharactersTyped = "usage.totalCharactersTyped"
    }

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private init() {
        loadFromStorage()
    }

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 录音完成时调用（完整参数）
    func recordSession(durationSeconds: Int, characterCount: Int) {
        totalRecordings += 1
        totalRecordingSeconds += durationSeconds
        totalCharactersTyped += characterCount

        saveToStorage()
        print("[UsageStats] Recorded session: \(durationSeconds)s, \(characterCount) chars")
    }

    /// 录音完成时调用（仅字数，自动计算时长为30秒）
    func recordSession(characters: Int) {
        recordSession(durationSeconds: 30, characterCount: characters)
    }

    /// 格式化时长显示
    func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes > 0 {
            return "\(minutes) 分钟"
        }
        return "\(seconds) 秒"
    }

    // ----------------------------------------
    // MARK: - Private Helpers
    // ----------------------------------------

    private func loadFromStorage() {
        totalRecordings = defaults.integer(forKey: Key.totalRecordings.rawValue) ?? 0
        totalRecordingSeconds = defaults.integer(forKey: Key.totalRecordingSeconds.rawValue) ?? 0
        totalCharactersTyped = defaults.integer(forKey: Key.totalCharactersTyped.rawValue) ?? 0
    }

    private func saveToStorage() {
        defaults.set(totalRecordings, forKey: Key.totalRecordings.rawValue)
        defaults.set(totalRecordingSeconds, forKey: Key.totalRecordingSeconds.rawValue)
        defaults.set(totalCharactersTyped, forKey: Key.totalCharactersTyped.rawValue)
    }
}
