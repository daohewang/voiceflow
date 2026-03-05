/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 AppState.shared 全局状态
 * [OUTPUT]: 对外提供 SettingsWindowManager 单例，管理设置窗口的显示与隐藏
 * [POS]: VoiceFlow 的设置窗口管理器，被 MenuBarView 调用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI
import AppKit

// ========================================
// MARK: - Settings Window Manager
// ========================================

@MainActor
final class SettingsWindowManager: NSObject, ObservableObject, NSWindowDelegate {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = SettingsWindowManager()

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    private var window: NSWindow?

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private override init() {
        super.init()
    }

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 显示设置窗口
    func showSettings() {
        print("[SettingsWindowManager] showSettings() called")

        // 如果窗口已存在，直接激活
        if let existingWindow = window {
            print("[SettingsWindowManager] Window exists, activating...")
            activateAndShowWindow(existingWindow)
            return
        }

        print("[SettingsWindowManager] Creating new window...")

        // 临时切换到普通应用模式（这样窗口才能显示）
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 创建设置视图
        let settingsView = SettingsView()
            .environment(AppState.shared)

        // 创建窗口
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "VoiceFlow 设置"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // 使用 NSHostingView
        let hosting = NSHostingView(rootView: AnyView(settingsView))
        newWindow.contentView = hosting

        // 设置代理
        newWindow.delegate = self

        self.window = newWindow

        // 显示窗口
        activateAndShowWindow(newWindow)
        print("[SettingsWindowManager] Window should be visible now")
    }

    private func activateAndShowWindow(_ window: NSWindow) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// 关闭设置窗口
    func closeSettings() {
        window?.close()
    }

    // ----------------------------------------
    // MARK: - NSWindowDelegate
    // ----------------------------------------

    func windowWillClose(_ notification: Notification) {
        // 延迟切换回 accessory 模式，避免闪烁
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.window = nil
            // 切换回菜单栏模式
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
