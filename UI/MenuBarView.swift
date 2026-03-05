/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 AppState 全局状态
 * [OUTPUT]: 对外提供 MenuBarView 视图组件
 * [POS]: VoiceFlow 的菜单栏主界面，展示四状态 UI (Idle/Recording/Processing/Error)
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI

// ========================================
// MARK: - Menu Bar View
// ========================================

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    // ----------------------------------------
    // MARK: - Body
    // ----------------------------------------

    var body: some View {
        VStack(spacing: 0) {
            // ----------------------------------------
            // Header
            // ----------------------------------------
            headerView

            Divider()

            // ----------------------------------------
            // Content - State Machine
            // ----------------------------------------
            contentView
                .frame(minHeight: 120, maxHeight: 300)

            Divider()

            // ----------------------------------------
            // Footer
            // ----------------------------------------
            footerView
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // ----------------------------------------
    // MARK: - Header
    // ----------------------------------------

    private var headerView: some View {
        HStack {
            statusIcon
            Text(statusTitle)
                .font(.system(.headline, design: .rounded))
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusIcon: some View {
        Group {
            switch appState.currentStatus {
            case .idle:
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
            case .recording:
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
            case .processing:
                ProgressView()
                    .scaleEffect(0.7)
            case .injecting:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 24)
    }

    private var statusBadge: some View {
        Group {
            switch appState.currentStatus {
            case .idle:
                EmptyView()
            case .recording:
                Text("REC")
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red)
                    .clipShape(Capsule())
            case .processing:
                Text("处理中")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .injecting:
                Text("完成")
                    .font(.caption2)
                    .foregroundStyle(.green)
            case .error:
                Text("错误")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusTitle: String {
        switch appState.currentStatus {
        case .idle:
            return "VoiceFlow"
        case .recording:
            return "正在录音..."
        case .processing:
            return "正在处理..."
        case .injecting:
            return "已注入"
        case .error(let message):
            return message
        }
    }

    // ----------------------------------------
    // MARK: - Content
    // ----------------------------------------

    @ViewBuilder
    private var contentView: some View {
        switch appState.currentStatus {
        case .idle:
            idleContent
        case .recording:
            recordingContent
        case .processing:
            processingContent
        case .injecting:
            injectingContent
        case .error:
            errorContent
        }
    }

    private var idleContent: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("按下快捷键开始录音")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Text(appState.hotkeyConfig.displayString)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var recordingContent: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.asrText)
                            .font(.system(.body, design: .rounded))
                            .textSelection(.enabled)
                            .id("asrText")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .onChange(of: appState.asrText) { _, newValue in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("asrText", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var processingContent: some View {
        VStack(spacing: 12) {
            // ASR 原文 (上部分)
            VStack(alignment: .leading, spacing: 4) {
                Text("原文")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(appState.asrText)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Divider()

            // LLM 润色结果 (下部分)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("润色结果")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                }
                Text(appState.llmText.isEmpty ? "生成中..." : appState.llmText)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(appState.llmText.isEmpty ? .tertiary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private var injectingContent: some View {
        VStack(spacing: 12) {
            // 成功动画
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("文本已注入")
                .font(.system(.headline, design: .rounded))

            if !appState.llmText.isEmpty {
                Text(appState.llmText)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var errorContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)

            Text("出错了")
                .font(.system(.headline, design: .rounded))

            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("重试") {
                appState.clearError()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // ----------------------------------------
    // MARK: - Footer
    // ----------------------------------------

    private var footerView: some View {
        HStack {
            // Settings Button
            Button {
                SettingsWindowManager.shared.showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("设置")

            Spacer()

            // Quit Button - ⌘Q 在 MenuBarExtra 中无效，改用 NSApp menu 注册
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
    state.llmText = "润色后的文本内容"
    return MenuBarView()
        .environment(state)
}

#Preview("Error") {
    let state = AppState()
    state.setError("无法连接到服务器")
    return MenuBarView()
        .environment(state)
}
