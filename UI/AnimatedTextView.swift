/**
 * [INPUT]: 依赖 SwiftUI 框架
 * [OUTPUT]: 对外提供 AnimatedTextView 组件，用于文本淡入淡出过渡
 * [POS]: VoiceFlow 的 UI 组件，被 MenuBarView 使用，实现 ASR/LLM 文本的平滑过渡
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI

// ========================================
// MARK: - Animated Text View
// ========================================

/// 带淡入淡出动画的文本视图
/// 用于 ASR 文本到 LLM 文本的平滑过渡
struct AnimatedTextView: View {

    // ----------------------------------------
    // MARK: - Properties
    // ----------------------------------------

    /// 当前显示的文本
    let text: String

    /// 文本样式
    let style: TextDisplayStyle

    /// 动画时长 (默认 200ms)
    let animationDuration: Double

    /// 是否显示占位符
    let showPlaceholder: Bool

    /// 占位符文本
    let placeholder: String

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    @State private var opacity: Double = 1.0
    @State private var previousText: String = ""
    @State private var isTransitioning: Bool = false

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    init(
        text: String,
        style: TextDisplayStyle = .body,
        animationDuration: Double = 0.2,
        showPlaceholder: Bool = true,
        placeholder: String = "等待输入..."
    ) {
        self.text = text
        self.style = style
        self.animationDuration = animationDuration
        self.showPlaceholder = showPlaceholder
        self.placeholder = placeholder
    }

    // ----------------------------------------
    // MARK: - Body
    // ----------------------------------------

    var body: some View {
        ZStack {
            if text.isEmpty && showPlaceholder {
                placeholderView
            } else {
                textView
            }
        }
        .onChange(of: text) { _, newValue in
            handleTextChange(newValue)
        }
    }

    // ----------------------------------------
    // MARK: - Subviews
    // ----------------------------------------

    @ViewBuilder
    private var textView: some View {
        if isTransitioning && !previousText.isEmpty {
            // 过渡期间：显示旧文本淡出 + 新文本淡入
            ZStack {
                Text(previousText)
                    .font(style.font)
                    .foregroundStyle(style.color.opacity(1.0 - opacity))
                    .multilineTextAlignment(.leading)

                Text(text)
                    .font(style.font)
                    .foregroundStyle(style.color.opacity(opacity))
                    .multilineTextAlignment(.leading)
            }
        } else {
            Text(text)
                .font(style.font)
                .foregroundStyle(style.color)
                .multilineTextAlignment(.leading)
        }
    }

    private var placeholderView: some View {
        Text(placeholder)
            .font(style.font)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.leading)
    }

    // ----------------------------------------
    // MARK: - Animation Logic
    // ----------------------------------------

    private func handleTextChange(_ newValue: String) {
        guard !previousText.isEmpty && !newValue.isEmpty else {
            previousText = newValue
            return
        }

        // 开始过渡动画
        isTransitioning = true
        opacity = 0.0

        withAnimation(.easeInOut(duration: animationDuration)) {
            opacity = 1.0
        }

        // 动画完成后清理
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.05) {
            isTransitioning = false
            previousText = newValue
        }
    }
}

// ========================================
// MARK: - Text Display Style
// ========================================

/// 文本显示样式配置
enum TextDisplayStyle {
    case asrText      // ASR 实时文本
    case llmText      // LLM 润色结果
    case body         // 通用正文
    case caption      // 说明文字
    case custom(font: Font, color: Color)

    var font: Font {
        switch self {
        case .asrText:
            return .system(.body, design: .rounded)
        case .llmText:
            return .system(.body, design: .rounded)
        case .body:
            return .system(.body, design: .rounded)
        case .caption:
            return .system(.caption, design: .rounded)
        case .custom(let font, _):
            return font
        }
    }

    var color: Color {
        switch self {
        case .asrText:
            return .primary
        case .llmText:
            return .primary
        case .body:
            return .primary
        case .caption:
            return .secondary
        case .custom(_, let color):
            return color
        }
    }
}

// ========================================
// MARK: - Transition Text View (简化版)
// ========================================

/// 简化版过渡文本视图
/// 使用 opacity 动画在两个文本之间切换
struct TransitionTextView: View {

    let fromText: String
    let toText: String
    let isTransitioning: Bool
    let style: TextDisplayStyle

    var body: some View {
        ZStack {
            if isTransitioning {
                // 交叉淡入淡出
                Text(fromText)
                    .font(style.font)
                    .foregroundStyle(style.color)
                    .opacity(isTransitioning ? 0 : 1)

                Text(toText)
                    .font(style.font)
                    .foregroundStyle(style.color)
                    .opacity(isTransitioning ? 1 : 0)
            } else {
                Text(toText)
                    .font(style.font)
                    .foregroundStyle(style.color)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isTransitioning)
    }
}

// ========================================
// MARK: - Animated Text Container
// ========================================

/// 容器视图：管理 ASR -> LLM 的文本过渡
struct AnimatedTextContainer: View {

    let asrText: String
    let llmText: String
    let state: AppState.State

    @State private var displayText: String = ""
    @State private var showAsr: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state == .recording {
                // 录音中：显示 ASR 文本
                AnimatedTextView(
                    text: asrText,
                    style: .asrText,
                    placeholder: "正在听..."
                )
            } else if state == .processing {
                // 处理中：显示 LLM 文本（带过渡）
                VStack(alignment: .leading, spacing: 4) {
                    Text("原文")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(asrText)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        Text("润色结果")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        if llmText.isEmpty {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }

                    AnimatedTextView(
                        text: llmText,
                        style: .llmText,
                        showPlaceholder: false
                    )
                }
            } else {
                // 其他状态
                AnimatedTextView(
                    text: displayText,
                    style: .body
                )
            }
        }
        .onChange(of: state) { _, newState in
            handleStateChange(newState)
        }
    }

    private func handleStateChange(_ newState: AppState.State) {
        switch newState {
        case .recording:
            displayText = asrText
            showAsr = true
        case .processing:
            showAsr = false
        case .idle, .injecting, .error:
            displayText = ""
        }
    }
}

// ========================================
// MARK: - Preview
// ========================================

#Preview("AnimatedTextView - Empty") {
    AnimatedTextView(text: "", placeholder: "等待输入...")
        .padding()
        .frame(width: 300)
}

#Preview("AnimatedTextView - With Text") {
    AnimatedTextView(
        text: "这是一段测试文本，用于展示动画效果。",
        style: .body
    )
    .padding()
    .frame(width: 300)
}

#Preview("TransitionTextView") {
    struct Preview: View {
        @State private var isTransitioning = false

        var body: some View {
            VStack(spacing: 20) {
                TransitionTextView(
                    fromText: "原始文本",
                    toText: "新文本",
                    isTransitioning: isTransitioning,
                    style: .body
                )

                Button("切换") {
                    isTransitioning.toggle()
                }
            }
            .padding()
            .frame(width: 300)
        }
    }

    return Preview()
}
