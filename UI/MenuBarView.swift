/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 AppState 全局状态
 * [OUTPUT]: 对外提供 MenuBarView 视图组件
 * [POS]: VoiceFlow 的菜单栏下拉界面，提供快捷操作入口
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI

// ========================================
// MARK: - Menu Bar View
// ========================================

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // 主内容区
            mainContent

            Divider()
                .padding(.horizontal, 12)

            // 底部操作区
            footerSection
        }
        .frame(width: 280)
        .padding(.vertical, 8)
    }

    // ========================================
    // MARK: - Main Content
    // ========================================

    @ViewBuilder
    private var mainContent: some View {
        switch appState.currentStatus {
        case .idle:
            idleView
        case .recording:
            recordingView
        case .processing:
            processingView
        case .injecting:
            injectedView
        case .error:
            errorView
        }
    }

    // ----------------------------------------
    // Idle State
    // ----------------------------------------

    private var idleView: some View {
        VStack(spacing: 16) {
            // Logo & Title
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "ec4899"), Color(hex: "8b5cf6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("VoiceFlow")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Text("语音输入，智能润色")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            // 快捷键提示
            HStack(spacing: 6) {
                Text("按下")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)

                Text(appState.hotkeyConfig.displayString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )

                Text("开始录音")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)
        }
    }

    // ----------------------------------------
    // Recording State
    // ----------------------------------------

    private var recordingView: some View {
        VStack(spacing: 12) {
            // 状态指示
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .symbolEffect(.pulse)

                Text("正在录音...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                Spacer()

                Text("再次按下快捷键结束")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // 实时文本
            if !appState.asrText.isEmpty {
                ScrollView {
                    Text(appState.asrText)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
                .frame(maxHeight: 120)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("等待语音输入...")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 80)
            }

            Spacer(minLength: 8)
        }
    }

    // ----------------------------------------
    // Processing State
    // ----------------------------------------

    private var processingView: some View {
        VStack(spacing: 12) {
            // 状态指示
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)

                Text("正在处理...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // 原文
            if !appState.asrText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("原文")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)

                    Text(appState.asrText)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            }

            // 润色结果
            VStack(alignment: .leading, spacing: 4) {
                Text("润色结果")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)

                if appState.llmText.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("生成中...")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(appState.llmText)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            Spacer(minLength: 8)
        }
    }

    // ----------------------------------------
    // Injected State
    // ----------------------------------------

    private var injectedView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("文本已注入")
                .font(.system(size: 14, weight: .medium, design: .rounded))

            if !appState.llmText.isEmpty {
                Text(appState.llmText)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .onAppear {
            // 2秒后自动回到 idle
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if appState.currentStatus == .injecting {
                    appState.currentStatus = .idle
                    appState.asrText = ""
                    appState.llmText = ""
                }
            }
        }
    }

    // ----------------------------------------
    // Error State
    // ----------------------------------------

    private var errorView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)

            Text("出错了")
                .font(.system(size: 14, weight: .medium, design: .rounded))

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                appState.clearError()
            } label: {
                Text("重试")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()
        }
    }

    // ========================================
    // MARK: - Footer Section
    // ========================================

    private var footerSection: some View {
        HStack(spacing: 0) {
            // 设置按钮
            Button {
                SettingsWindowManager.shared.showSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                    Text("设置")
                        .font(.system(size: 12, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // 退出按钮
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                    Text("退出")
                        .font(.system(size: 12, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// ========================================
// MARK: - Preview
// ========================================

#Preview("Idle") {
    MenuBarView()
        .environment(AppState())
}

#Preview("Recording") {
    let state = AppState()
    state.currentStatus = .recording
    state.asrText = "这是一段测试文本，用于展示录音状态下的界面效果..."
    return MenuBarView()
        .environment(state)
}

#Preview("Processing") {
    let state = AppState()
    state.currentStatus = .processing
    state.asrText = "原始录音文本"
    state.llmText = ""
    return MenuBarView()
        .environment(state)
}
