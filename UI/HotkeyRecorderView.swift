/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 HotkeyConfig 模型
 * [OUTPUT]: 对外提供 HotkeyRecorderView 组件
 * [POS]: VoiceFlow 的快捷键录制视图，被 SettingsView 使用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI
import AppKit
import Carbon

// ========================================
// MARK: - Hotkey Recorder View
// ========================================

struct HotkeyRecorderView: NSViewRepresentable {

    let config: HotkeyConfig
    @Binding var isRecording: Bool
    let onConfigChange: @Sendable (HotkeyConfig) -> Void

    // ----------------------------------------
    // MARK: - NSViewRepresentable
    // ----------------------------------------

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = isRecording ? "按下新快捷键..." : config.displayString
        context.coordinator.updateBindings(
            isRecording: isRecording,
            onIsRecordingChange: { newValue in
                Task { @MainActor in
                    isRecording = newValue
                }
            },
            onConfigChange: onConfigChange
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(config: config)
    }

    // ========================================
    // MARK: - Coordinator
    // ========================================

    class Coordinator: NSObject {

        var config: HotkeyConfig
        var isRecordingFlag: Bool = false
        private var eventMonitor: Any?
        private var localMonitor: Any?

        private var onIsRecordingChange: (@Sendable (Bool) -> Void)?
        private var onConfigChange: (@Sendable (HotkeyConfig) -> Void)?

        init(config: HotkeyConfig) {
            self.config = config
        }

        deinit {
            cleanupMonitors()
        }

        func updateBindings(
            isRecording: Bool,
            onIsRecordingChange: @escaping @Sendable (Bool) -> Void,
            onConfigChange: @escaping @Sendable (HotkeyConfig) -> Void
        ) {
            self.isRecordingFlag = isRecording
            self.onIsRecordingChange = onIsRecordingChange
            self.onConfigChange = onConfigChange
        }

        @objc func buttonClicked() {
            guard !isRecordingFlag else { return }

            isRecordingFlag = true
            onIsRecordingChange?(true)
            startMonitoring()
        }

        private func startMonitoring() {
            // 本地监听（应用内）
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingFlag else { return event }

                if let newConfig = self.processEvent(event) {
                    self.handleNewConfig(newConfig)
                    return nil // 消费事件
                }

                return event
            }

            // 全局监听（应用外）- 需要辅助功能权限
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingFlag else { return }

                if let newConfig = self.processEvent(event) {
                    self.handleNewConfig(newConfig)
                }
            }
        }

        private func handleNewConfig(_ newConfig: HotkeyConfig) {
            cleanupMonitors()
            isRecordingFlag = false
            onConfigChange?(newConfig)
            onIsRecordingChange?(false)
        }

        private func cleanupMonitors() {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }

        private func processEvent(_ event: NSEvent) -> HotkeyConfig? {
            let flags = event.modifierFlags

            // 忽略单独的修饰键
            if event.keyCode == 54 || event.keyCode == 55 || // Command
               event.keyCode == 56 || event.keyCode == 57 || // Shift
               event.keyCode == 58 || event.keyCode == 59 || // Option
               event.keyCode == 59 || event.keyCode == 62 {  // Control
                return nil
            }

            // 需要至少一个修饰键
            let hasModifier = flags.contains(.command) ||
                              flags.contains(.shift) ||
                              flags.contains(.control) ||
                              flags.contains(.option)

            guard hasModifier else { return nil }

            // 构建 CGEventFlags
            var cgFlags: CGEventFlags = []
            if flags.contains(.command) { cgFlags.insert(.maskCommand) }
            if flags.contains(.shift) { cgFlags.insert(.maskShift) }
            if flags.contains(.control) { cgFlags.insert(.maskControl) }
            if flags.contains(.option) { cgFlags.insert(.maskAlternate) }

            return HotkeyConfig(keyCode: event.keyCode, modifiers: cgFlags)
        }
    }
}
