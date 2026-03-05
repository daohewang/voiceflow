/**
 * [INPUT]: 依赖 SwiftUI 框架
 * [OUTPUT]: 对外提供 RecordingIndicatorManager 单例，管理录音指示器窗口
 * [POS]: VoiceFlow 的录音状态指示器，被 HotkeyMonitor 触发
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI
import AppKit

// ========================================
// MARK: - Recording Indicator Manager
// ========================================

@MainActor
final class RecordingIndicatorManager {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = RecordingIndicatorManager()

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    private var panel: NSPanel?

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private init() {}

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 显示录音指示器
    func show() {
        // 确保在主线程
        guard Thread.isMainThread else {
            Task { @MainActor in
                self.show()
            }
            return
        }

        // 如果已存在，不重复创建
        if panel != nil { return }

        // 创建面板
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = false
        panel.ignoresMouseEvents = true

        // 设置窗口位置（屏幕顶部中央）
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 140) / 2
            let y = screenFrame.height - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // 创建 SwiftUI 视图
        let indicatorView = NSHostingView(rootView: RecordingIndicatorCapsule())
        indicatorView.frame = NSRect(x: 0, y: 0, width: 140, height: 44)
        panel.contentView = indicatorView

        self.panel = panel
        panel.orderFrontRegardless()
    }

    /// 隐藏录音指示器
    func hide() {
        guard Thread.isMainThread else {
            Task { @MainActor in
                self.hide()
            }
            return
        }

        panel?.orderOut(nil)
        panel = nil
    }
}

// ========================================
// MARK: - Recording Indicator View
// ========================================

struct RecordingIndicatorCapsule: View {
    var body: some View {
        HStack(spacing: 8) {
            // 红色脉冲圆点
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)

            Text("录音中...")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
        )
        .frame(width: 140, height: 44)
    }
}

// ========================================
// MARK: - Preview
// ========================================

#Preview {
    RecordingIndicatorCapsule()
}
