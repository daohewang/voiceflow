/**
 * [INPUT]: 无外部依赖，仅依赖 Foundation/SwiftUI
 * [OUTPUT]: 对外提供 @Observable 全局状态管理
 * [POS]: VoiceFlow 应用的状态中枢，被所有模块引用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation
import SwiftUI

// ========================================
// MARK: - Application State
// ========================================

@Observable
class AppState {

    // ----------------------------------------
    // MARK: - Singleton (for SettingsWindowManager)
    // ----------------------------------------

    @MainActor static let shared = AppState()

    // ----------------------------------------
    // MARK: - State Machine
    // ----------------------------------------

    enum State: Equatable {
        case idle
        case recording
        case processing
        case injecting
        case error(message: String)

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    var currentStatus: State = .idle

    // ----------------------------------------
    // MARK: - Text Content
    // ----------------------------------------

    var asrText: String = ""           // ASR 实时文本
    var llmText: String = ""           // LLM 润色结果
    var displayText: String = ""       // UI 显示文本

    // ----------------------------------------
    // MARK: - Race Condition Protection
    // ----------------------------------------

    /// 当前会话 ID，用于防止竞态条件
    var currentSessionId: UUID = UUID()

    func startNewSession() {
        currentSessionId = UUID()
        asrText = ""
        llmText = ""
        displayText = ""
        errorMessage = nil
    }

    func isValidSession(_ id: UUID) -> Bool {
        return id == currentSessionId
    }

    // ----------------------------------------
    // MARK: - Error Handling
    // ----------------------------------------

    var errorMessage: String?

    func setError(_ message: String) {
        currentStatus = .error(message: message)
        errorMessage = message
    }

    func clearError() {
        if case .error = currentStatus {
            currentStatus = .idle
        }
        errorMessage = nil
    }

    // ----------------------------------------
    // MARK: - Configuration
    // ----------------------------------------

    var selectedStyleId: String = "default"
    var apiKeyElevenLabs: String?
    var apiKeyOpenRouter: String?
    var hotkeyConfig: HotkeyConfig = .default

    /// 加载保存的配置
    func loadSavedConfig() {
        if let data = UserDefaults.standard.data(forKey: "hotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            hotkeyConfig = config
        }
    }

    /// 保存快捷键配置
    @MainActor
    func saveHotkeyConfig(_ config: HotkeyConfig) {
        hotkeyConfig = config
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "hotkeyConfig")
        }
        // 通知 HotkeyMonitor 更新
        Task { @MainActor in
            HotkeyMonitor.shared.updateConfig(config)
        }
    }

    // ----------------------------------------
    // MARK: - Animation State
    // ----------------------------------------

    var isTransitioning: Bool = false
    var transitionProgress: Double = 0.0

    // ----------------------------------------
    // MARK: - Debug
    // ----------------------------------------

    var debugLogs: [String] = []

    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        debugLogs.append("[\(timestamp)] \(message)")
        // Keep only last 100 logs
        if debugLogs.count > 100 {
            debugLogs.removeFirst(debugLogs.count - 100)
        }
    }
}
