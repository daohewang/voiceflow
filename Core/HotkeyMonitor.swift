/**
 * [INPUT]: 依赖 ApplicationServices (CGEventTap)、AppState 全局状态、PermissionManager 权限检查
 * [OUTPUT]: 对外提供 HotkeyMonitor 单例，管理全局快捷键监听
 * [POS]: VoiceFlow 的快捷键中枢，被 VoiceFlowApp 调用启动
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation
import ApplicationServices
import Carbon
import AppKit

// ========================================
// MARK: - Hotkey Monitor
// ========================================

@MainActor
@Observable
final class HotkeyMonitor {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = HotkeyMonitor()

    // ----------------------------------------
    // MARK: - Configuration
    // ----------------------------------------

    /// 当前快捷键配置
    private var config: HotkeyConfig = .default

    /// 更新快捷键配置并重启事件监听
    func updateConfig(_ newConfig: HotkeyConfig) {
        config = newConfig
        print("[HotkeyMonitor] Config updated to: \(newConfig.displayString)")

        // 重启监听以应用新配置
        if isMonitoring {
            stopMonitoring()
            startMonitoring()
            print("[HotkeyMonitor] Monitor restarted with new config")
        }
    }

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    private(set) var isMonitoring: Bool = false

    /// CGEventTap 相关
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// NSEvent 全局监听（备用方案）
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// 录音状态
    private var isRecording: Bool = false

    // ----------------------------------------
    // MARK: - Callbacks
    // ----------------------------------------

    /// 开始录音回调
    var onStartRecording: (() -> Void)?

    /// 停止录音回调
    var onStopRecording: (() -> Void)?

    /// 取消录音回调
    var onCancelRecording: (() -> Void)?

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private init() {}

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 启动快捷键监听
    /// - Returns: 是否成功启动
    @discardableResult
    func startMonitoring() -> Bool {
        guard !isMonitoring else { return true }

        // 检查辅助功能权限
        let trusted = AXIsProcessTrusted()
        print("[HotkeyMonitor] Accessibility trusted: \(trusted)")

        if !trusted {
            // 弹出权限请求对话框
            _ = PermissionManager.shared.requestAccessibilityPermission()
            print("[HotkeyMonitor] Accessibility permission not granted, requesting...")
        }

        // 尝试方案 1: CGEventTap (最可靠，但需要权限)
        if trusted {
            let tapSuccess = setupCGEventTap()
            if tapSuccess {
                isMonitoring = true
                print("[HotkeyMonitor] Started monitoring via CGEventTap")
                return true
            }
            print("[HotkeyMonitor] CGEventTap failed, falling back to NSEvent monitor")
        }

        // 方案 2: NSEvent 全局监听 (权限要求较低)
        setupNSEventMonitor()
        isMonitoring = true
        print("[HotkeyMonitor] Started monitoring via NSEvent global monitor")
        return true
    }

    /// 重新启用被系统禁用的 CGEventTap
    fileprivate func reenableTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyMonitor] CGEventTap re-enabled after disable")
    }

    /// 停止快捷键监听
    func stopMonitoring() {
        // 清理 CGEventTap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        // 清理 NSEvent 监听
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        isMonitoring = false
        print("[HotkeyMonitor] Stopped monitoring")
    }

    // ----------------------------------------
    // MARK: - CGEventTap Setup
    // ----------------------------------------

    private func setupCGEventTap() -> Bool {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

            // macOS 超时后会自动 disable tap，必须在此重新启用，否则之后所有按键都失效
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                monitor.reenableTap()
                return nil
            }

            return monitor.handleCGEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[HotkeyMonitor] Failed to create CGEventTap")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = source else {
            print("[HotkeyMonitor] Failed to create run loop source")
            return false
        }

        // 添加到 主 run loop
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source

        return true
    }

    // ----------------------------------------
    // MARK: - NSEvent Monitor Setup (Fallback)
    // ----------------------------------------

    private func setupNSEventMonitor() {
        // 全局监听 keyDown
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleNSEvent(event)
            }
        }

        // 本地监听 keyDown (应用内)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleNSEvent(event)
            }
            return event // 不拦截
        }
    }

    // ----------------------------------------
    // MARK: - CGEvent Handling
    // ----------------------------------------

    private func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        // 长按重复键忽略，只响应首次按下
        guard !isRepeat else { return Unmanaged.passUnretained(event) }

        print("[HotkeyMonitor] CGEvent KeyDown - keyCode: \(keyCode), flags: \(event.flags.rawValue)")

        // Escape 取消录音
        if keyCode == 53 {
            if isRecording { cancelRecording() }
            return Unmanaged.passUnretained(event)
        }

        // 配置的快捷键：start / stop 切换
        guard isConfiguredHotkeyCG(event: event) else {
            return Unmanaged.passUnretained(event)
        }

        print("[HotkeyMonitor] ✅ Hotkey MATCHED!")
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
        return nil  // 拦截，不传给其他 app
    }

    /// 检查 CGEvent 是否为配置的快捷键
    private func isConfiguredHotkeyCG(event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(config.keyCode) else { return false }

        let flags = event.flags
        let configFlags = config.cgEventFlags

        // 只检查 4 个标准修饰键，忽略其他标志位
        let relevantMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]

        let eventModifiers = flags.intersection(relevantMask)
        let configModifiers = configFlags.intersection(relevantMask)

        return eventModifiers == configModifiers
    }

    // ----------------------------------------
    // MARK: - NSEvent Handling (Fallback)
    // ----------------------------------------

    private func handleNSEvent(_ event: NSEvent) {
        guard event.type == .keyDown, !event.isARepeat else { return }

        let keyCode = event.keyCode
        print("[HotkeyMonitor] NSEvent KeyDown - keyCode: \(keyCode)")

        if keyCode == 53 {
            if isRecording { cancelRecording() }
            return
        }

        guard isConfiguredHotkeyNS(event: event) else { return }

        print("[HotkeyMonitor] ✅ Hotkey MATCHED via NSEvent!")
        if isRecording { stopRecording() } else { startRecording() }
    }

    /// 检查 NSEvent 是否为配置的快捷键
    private func isConfiguredHotkeyNS(event: NSEvent) -> Bool {
        guard event.keyCode == UInt16(config.keyCode) else { return false }

        let flags = event.modifierFlags
        let configFlags = config.cgEventFlags

        // 双向检查：event 和 config 的修饰键必须完全匹配
        let configHasCommand = !configFlags.intersection(.maskCommand).isEmpty
        let configHasShift = !configFlags.intersection(.maskShift).isEmpty
        let configHasAlt = !configFlags.intersection(.maskAlternate).isEmpty
        let configHasControl = !configFlags.intersection(.maskControl).isEmpty

        let matchCommand = flags.contains(.command) == configHasCommand
        let matchShift = flags.contains(.shift) == configHasShift
        let matchAlt = flags.contains(.option) == configHasAlt
        let matchControl = flags.contains(.control) == configHasControl

        return matchCommand && matchShift && matchAlt && matchControl
    }

    // ----------------------------------------
    // MARK: - Recording Control
    // ----------------------------------------

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        print("[HotkeyMonitor] → startRecording callback")
        Task { @MainActor in
            onStartRecording?()
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        print("[HotkeyMonitor] → stopRecording callback")
        Task { @MainActor in
            onStopRecording?()
        }
    }

    private func cancelRecording() {
        isRecording = false
        print("[HotkeyMonitor] → cancelRecording callback")
        Task { @MainActor in
            onCancelRecording?()
        }
    }
}

// ========================================
// MARK: - CGEventFlags Extension
// ========================================

private extension CGEventFlags {
    func contains(_ flag: CGEventFlags) -> Bool {
        return !self.intersection(flag).isEmpty
    }
}
