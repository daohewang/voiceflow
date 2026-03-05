/**
 * [INPUT]: 依赖 ApplicationServices (AXUIElement)、AppKit (NSPasteboard)、AppState
 * [OUTPUT]: 对外提供 TextInjector 单例，支持剪贴板注入和键盘模拟
 * [POS]: VoiceFlow 的文本注入中枢，被录音流程调用注入润色后的文本
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation
import ApplicationServices
import AppKit

// ========================================
// MARK: - Text Injector
// ========================================

@MainActor
@Observable
final class TextInjector {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = TextInjector()

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    private(set) var isInjecting: Bool = false

    /// 原始剪贴板内容 (用于恢复)
    private var originalClipboardContent: String?

    // ----------------------------------------
    // MARK: - Configuration
    // ----------------------------------------

    /// 检测剪贴板变化的延迟时间 (100ms)
    private let detectionDelay: TimeInterval = 0.1

    /// 完成后额外等待时间 (确保 Electron/终端完成粘贴)
    private let completionDelay: TimeInterval = 0.2

    /// 注入的文本 (用于变化检测)
    private var injectedText: String = ""

    // ----------------------------------------
    // MARK: - Callbacks
    // ----------------------------------------

    /// 注入完成回调
    var onInjectComplete: (() -> Void)?

    /// 注入失败回调
    var onInjectError: ((TextInjectorError) -> Void)?

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private init() {}

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 注入文本到当前活动应用
    /// - Parameter text: 要注入的文本
    func injectText(_ text: String) {
        guard !isInjecting else { return }
        guard PermissionManager.shared.accessibilityStatus == .granted else {
            onInjectError?(.permissionDenied)
            return
        }

        isInjecting = true
        injectedText = text

        // Step 1: 保存原始剪贴板内容
        saveClipboardContent()

        // Step 2: 设置新文本到剪贴板
        setClipboardContent(text)

        // Step 3: 模拟 Cmd+V
        simulatePaste()

        // Step 4: 100ms 后检测变化，决定是否恢复
        Task {
            try? await Task.sleep(nanoseconds: UInt64(detectionDelay * 1_000_000_000))
            await handleClipboardDetection()

            // 额外等待确保 Electron/终端完成
            try? await Task.sleep(nanoseconds: UInt64(completionDelay * 1_000_000_000))
            isInjecting = false
            onInjectComplete?()
        }
    }

    /// 取消注入 (恢复剪贴板)
    func cancel() {
        restoreClipboardContent()
        isInjecting = false
    }

    // ----------------------------------------
    // MARK: - Clipboard Operations
    // ----------------------------------------

    /// 保存当前剪贴板内容
    private func saveClipboardContent() {
        let pasteboard = NSPasteboard.general
        if let content = pasteboard.string(forType: .string) {
            originalClipboardContent = content
        } else {
            originalClipboardContent = nil
        }
    }

    /// 设置剪贴板内容
    private func setClipboardContent(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// 恢复原始剪贴板内容
    private func restoreClipboardContent() {
        guard let content = originalClipboardContent else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        originalClipboardContent = nil
    }

    // ----------------------------------------
    // MARK: - Clipboard Change Detection
    // ----------------------------------------

    /// 检测剪贴板变化并决定是否恢复
    private func handleClipboardDetection() {
        // 如果剪贴板内容仍然是我们注入的文本，说明应用没有修改剪贴板
        // 可以安全恢复原始内容
        let pasteboard = NSPasteboard.general
        if let currentContent = pasteboard.string(forType: .string),
           currentContent == injectedText {
            // 剪贴板未被修改，恢复原始内容
            restoreClipboardContent()
        }
        // 如果剪贴板已被修改（内容不同），保留新内容，不恢复
    }

    // ----------------------------------------
    // MARK: - Keyboard Simulation
    // ----------------------------------------

    /// 模拟 Cmd+V 粘贴操作
    private func simulatePaste() {
        // 创建 Cmd+V 按键事件
        let cmdKey: CGEventFlags = .maskCommand
        let vKeyCode: CGKeyCode = 9  // V 键的 keyCode

        // KeyDown 事件
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: true
        ) else {
            onInjectError?(.eventCreationFailed)
            return
        }
        keyDown.flags = cmdKey

        // KeyUp 事件
        guard let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: false
        ) else {
            onInjectError?(.eventCreationFailed)
            return
        }
        keyUp.flags = cmdKey

        // 发送事件
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }

    // ----------------------------------------
    // MARK: - Clipboard Change Detection
    // ----------------------------------------

    /// 检测剪贴板内容是否变化
    /// - Parameter expectedContent: 期望的内容
    /// - Returns: 是否检测到变化
    func detectClipboardChange(expectedContent: String) -> Bool {
        let pasteboard = NSPasteboard.general
        guard let currentContent = pasteboard.string(forType: .string) else {
            return false
        }
        return currentContent == expectedContent
    }

    /// 处理剪贴板变化检测和智能恢复
    private func handleClipboardDetection() async {
        let pasteboard = NSPasteboard.general
        let currentContent = pasteboard.string(forType: .string)

        // 情况1: 剪贴板仍是我们注入的文本 → 被应用取走了，恢复原内容
        if currentContent == injectedText {
            restoreClipboardContent()
        }
        // 情况2: 剪贴板为空或变化了 → 应用可能修改了剪贴板，放弃恢复
        // (不做任何操作，保留当前剪贴板状态)

        injectedText = ""
    }
}

// ========================================
// MARK: - Text Injector Error
// ========================================

enum TextInjectorError: LocalizedError {
    case permissionDenied
    case eventCreationFailed
    case injectionTimeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要辅助功能权限才能注入文本"
        case .eventCreationFailed:
            return "无法创建键盘事件"
        case .injectionTimeout:
            return "文本注入超时"
        }
    }
}
