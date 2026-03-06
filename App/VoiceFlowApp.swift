/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 AppState 全局状态
 * [OUTPUT]: 对外提供 @main App 入口点
 * [POS]: VoiceFlow 应用的根入口，管理窗口 + 菜单栏生命周期
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI

// ========================================
// MARK: - VoiceFlow App
// ========================================

@main
struct VoiceFlowApp: App {
    @State private var appState = AppState.shared

    init() {
        VoiceFlowApp.setupApp()
    }

    var body: some Scene {
        // 主窗口
        WindowGroup {
            MainWindow()
                .environment(appState)
        }
        .defaultSize(width: 420, height: 560)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 VoiceFlow") {
                    SettingsWindowManager.shared.showSettings()
                }
            }

            CommandGroup(replacing: .appTermination) {
                Button("退出 VoiceFlow") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        // 菜单栏
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }

    // ----------------------------------------
    // MARK: - Menu Bar Icon
    // ----------------------------------------

    private var menuBarIcon: String {
        switch appState.currentStatus {
        case .idle:
            return "waveform.circle"
        case .recording:
            return "waveform.circle.fill"
        case .processing:
            return "waveform.circle.badge.spinner"
        case .injecting:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    // ----------------------------------------
    // MARK: - App Setup
    // ----------------------------------------

    private static func setupApp() {
        Task { @MainActor in
            // 加载保存的配置
            AppState.shared.loadSavedConfig()

            // 设置快捷键监听器
            HotkeyMonitor.shared.onStartRecording = {
                Task { @MainActor in
                    print("[VoiceFlowApp] Start recording triggered")
                    AppState.shared.currentStatus = .recording
                    AppState.shared.startNewSession()
                    RecordingCoordinator.shared.startRecording()
                }
            }

            HotkeyMonitor.shared.onStopRecording = {
                Task { @MainActor in
                    print("[VoiceFlowApp] Stop recording triggered")
                    RecordingCoordinator.shared.stopRecording()
                }
            }

            HotkeyMonitor.shared.onCancelRecording = {
                Task { @MainActor in
                    print("[VoiceFlowApp] Cancel recording triggered")
                    RecordingIndicatorManager.shared.hide()
                    RecordingCoordinator.shared.cancelRecording()
                }
            }

            // 启动监听
            HotkeyMonitor.shared.updateConfig(AppState.shared.hotkeyConfig)
            let success = HotkeyMonitor.shared.startMonitoring()
            print("[VoiceFlowApp] HotkeyMonitor started: \(success)")
        }
    }
}
