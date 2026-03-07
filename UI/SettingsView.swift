/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 AppState 全局状态
 * [OUTPUT]: 对外提供 SettingsView 视图组件
 * [POS]: VoiceFlow 的设置界面，提供 API Key 配置、风格模板选择、快捷键配置
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI
import ApplicationServices
import AppKit

// ========================================
// MARK: - Settings View
// ========================================

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SettingsTab = .apiKeys
    // ASR 提供商
    @State private var asrProvider: ASRProviderType = .elevenLabs
    @State private var elevenLabsKey: String = ""
    @State private var deepSeekASRKey: String = ""
    @State private var openAIASRKey: String = ""
    // LLM 提供商
    @State private var llmProvider: LLMProviderType = .openRouter
    @State private var openRouterKey: String = ""
    @State private var deepSeekLLMKey: String = ""
    @State private var miniMaxKey: String = ""
    @State private var zhiPuKey: String = ""
    @State private var kimiKey: String = ""
    // 显示/隐藏密钥
    @State private var showElevenLabsKey: Bool = false
    @State private var showOpenAIKey: Bool = false

    // ----------------------------------------
    // MARK: - Tabs
    // ----------------------------------------

    private enum SettingsTab: String, CaseIterable {
        case apiKeys = "API Keys"
        case style = "风格模板"
        case hotkey = "快捷键"
        case about = "关于"

        var icon: String {
            switch self {
            case .apiKeys: return "key.fill"
            case .style: return "paintbrush.fill"
            case .hotkey: return "keyboard.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    // ----------------------------------------
    // MARK: - Body
    // ----------------------------------------

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            tabBar

            Divider()

            // Content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadSettings()
        }
    }

    // ----------------------------------------
    // MARK: - Tab Bar
    // ----------------------------------------

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(.caption, design: .rounded))
                        Text(tab.rawValue)
                            .font(.system(.callout, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : .clear)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // ----------------------------------------
    // MARK: - Tab Content
    // ----------------------------------------

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .apiKeys:
            apiKeysContent
        case .style:
            styleContent
        case .hotkey:
            hotkeyContent
        case .about:
            aboutContent
        }
    }

    // ----------------------------------------
    // MARK: - API Keys Content
    // ----------------------------------------

    private var apiKeysContent: some View {
        Form {
            // MARK: - ASR 提供商选择
            Section {
                Picker("语音识别服务", selection: $asrProvider) {
                    ForEach(ASRProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                // 根据 ASR 提供商显示对应的 API Key 输入
                switch asrProvider {
                case .elevenLabs:
                    apiKeyField(
                        title: "ElevenLabs API Key",
                        key: $elevenLabsKey,
                        showKey: $showElevenLabsKey,
                        placeholder: "xi-...",
                        helpURL: "https://elevenlabs.io",
                        description: "用于 ElevenLabs Realtime STT 语音识别"
                    )
                case .deepSeek:
                    apiKeyField(
                        title: "DeepSeek API Key",
                        key: $deepSeekASRKey,
                        showKey: .constant(false),
                        placeholder: "sk-...",
                        helpURL: "https://platform.deepseek.com",
                        description: "用于 DeepSeek Whisper 语音识别"
                    )
                case .openAI:
                    apiKeyField(
                        title: "OpenAI API Key",
                        key: $openAIASRKey,
                        showKey: .constant(false),
                        placeholder: "sk-...",
                        helpURL: "https://platform.openai.com",
                        description: "用于 OpenAI Whisper 语音识别"
                    )
                }
            } header: {
                Text("语音识别 (ASR)")
                    .font(.system(.headline, design: .rounded))
            }

            // MARK: - LLM 提供商选择
            Section {
                Picker("文本润色服务", selection: $llmProvider) {
                    ForEach(LLMProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                // 根据 LLM 提供商显示对应的 API Key 输入
                switch llmProvider {
                case .openRouter:
                    apiKeyField(
                        title: "OpenRouter API Key",
                        key: $openRouterKey,
                        showKey: $showOpenAIKey,
                        placeholder: "sk-or-...",
                        helpURL: "https://openrouter.ai/keys",
                        description: "支持 GPT-4o、Claude、Gemini 等多种模型"
                    )
                case .deepSeek:
                    apiKeyField(
                        title: "DeepSeek API Key",
                        key: $deepSeekLLMKey,
                        showKey: .constant(false),
                        placeholder: "sk-...",
                        helpURL: "https://platform.deepseek.com",
                        description: "DeepSeek Chat 模型，性价比高"
                    )
                case .miniMax:
                    apiKeyField(
                        title: "MiniMax API Key",
                        key: $miniMaxKey,
                        showKey: .constant(false),
                        placeholder: "...",
                        helpURL: "https://www.minimaxi.com",
                        description: "MiniMax 大语言模型"
                    )
                case .zhiPu:
                    apiKeyField(
                        title: "智谱 API Key",
                        key: $zhiPuKey,
                        showKey: .constant(false),
                        placeholder: "...",
                        helpURL: "https://open.bigmodel.cn",
                        description: "智谱 GLM 大语言模型"
                    )
                case .kimi:
                    apiKeyField(
                        title: "Kimi API Key",
                        key: $kimiKey,
                        showKey: .constant(false),
                        placeholder: "sk-...",
                        helpURL: "https://platform.moonshot.cn",
                        description: "Moonshot Kimi 长上下文模型"
                    )
                }
            } header: {
                Text("文本润色 (LLM)")
                    .font(.system(.headline, design: .rounded))
            } footer: {
                VStack(spacing: 12) {
                    // 保存成功提示
                    if showSaveSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("保存成功！")
                                .foregroundStyle(.green)
                                .font(.caption.weight(.medium))
                        }
                        .transition(.opacity)
                    }

                    HStack {
                        Spacer()
                        Button("取消") {
                            loadSettings()
                        }
                        .buttonStyle(.bordered)

                        Button("保存") {
                            saveSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, 16)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // ----------------------------------------
    // MARK: - API Key Field Helper
    // ----------------------------------------

    @ViewBuilder
    private func apiKeyField(
        title: String,
        key: Binding<String>,
        showKey: Binding<Bool>,
        placeholder: String,
        helpURL: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                Spacer()
                Link("获取密钥", destination: URL(string: helpURL)!)
                    .font(.caption)
            }

            HStack {
                if showKey.wrappedValue {
                    TextField(placeholder, text: key)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField(placeholder, text: key)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    showKey.wrappedValue.toggle()
                } label: {
                    Image(systemName: showKey.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(description)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // ----------------------------------------
    // MARK: - Style Content
    // ----------------------------------------

    private var styleContent: some View {
        VStack(spacing: 16) {
            Text("风格模板")
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Text("选择文本润色风格，LLM 将根据选定风格改写您的语音输入")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Divider()

            // Style List (Placeholder - will be populated by StyleTemplate)
            ScrollView {
                VStack(spacing: 8) {
                    styleCard(id: "default", name: "默认", description: "保持原样，仅修正语法错误", icon: "doc.text")
                    styleCard(id: "formal", name: "正式", description: "转换为正式商务写作风格", icon: "building.2")
                    styleCard(id: "casual", name: "休闲", description: "轻松友好的日常沟通风格", icon: "face.smiling")
                    styleCard(id: "code", name: "代码注释", description: "适合代码注释的技术文档风格", icon: "chevron.left.forwardslash.chevron.right")
                }
                .padding()
            }

            Divider()

            HStack {
                Button("恢复默认") {
                    appState.selectedStyleId = "default"
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("当前: \(styleName(for: appState.selectedStyleId))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private func styleCard(id: String, name: String, description: String, icon: String) -> some View {
        Button {
            appState.selectedStyleId = id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(appState.selectedStyleId == id ? .white : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.selectedStyleId == id ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if appState.selectedStyleId == id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(appState.selectedStyleId == id ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func styleName(for id: String) -> String {
        switch id {
        case "default": return "默认"
        case "formal": return "正式"
        case "casual": return "休闲"
        case "code": return "代码注释"
        default: return "未知"
        }
    }

    // ----------------------------------------
    // MARK: - Hotkey Content
    // ----------------------------------------

    @State private var isRecordingHotkey: Bool = false
    @State private var hasAccessibilityPermission: Bool = false

    private var hotkeyContent: some View {
        VStack(spacing: 20) {
            Text("快捷键配置")
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Text("设置全局快捷键以快速启动录音")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // 权限状态警告
            if !hasAccessibilityPermission {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("缺少辅助功能权限")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                    }

                    Text("没有辅助功能权限，快捷键无法拦截按键事件。\n按键会先输入到当前应用，然后才触发动作。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("打开系统设置") {
                        // 打开系统设置的辅助功能面板
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal)
            }

            Divider()

            // Hotkey Configuration
            VStack(spacing: 16) {
                // 主快捷键录制
                HotkeyRecorderView(
                    config: appState.hotkeyConfig,
                    isRecording: $isRecordingHotkey
                ) { newConfig in
                    Task { @MainActor in
                        appState.saveHotkeyConfig(newConfig)
                        isRecordingHotkey = false
                    }
                }
                .padding(.horizontal)

                // 恢复默认按钮
                HStack {
                    Button("恢复默认") {
                        appState.saveHotkeyConfig(.default)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("当前: \(appState.hotkeyConfig.displayString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 8) {
                Text("使用说明")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("• 单击: 按住录音，松开停止\n• 双击: 切换模式（再按一次停止）\n• ESC: 取消当前录音")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
        .onAppear {
            checkAccessibilityPermission()
        }
    }

    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    // ----------------------------------------
    // MARK: - About Content
    // ----------------------------------------

    private var aboutContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            // App Name & Version
            VStack(spacing: 4) {
                Text("VoiceFlow")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text("版本 0.0.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("语音驱动的文本输入工具\n让您的声音变成完美的文字")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 100)

            // Links
            HStack(spacing: 24) {
                Link(destination: URL(string: "https://github.com")!) {
                    Label("GitHub", systemImage: "link")
                        .font(.caption)
                }

                Link(destination: URL(string: "mailto:support@voiceflow.app")!) {
                    Label("反馈", systemImage: "envelope")
                        .font(.caption)
                }
            }

            Spacer()

            // Footer
            Text("© 2024 VoiceFlow. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    // ----------------------------------------
    // MARK: - Actions
    // ----------------------------------------

    @State private var showSaveSuccess: Bool = false

    private func loadSettings() {
        // 从 Keychain 加载
        if let key = try? KeychainManager.shared.get(.elevenLabs) {
            elevenLabsKey = key
        }
        if let key = try? KeychainManager.shared.get(.openRouter) {
            openRouterKey = key
        }
    }

    private func saveSettings() {
        do {
            // 保存到 Keychain
            if elevenLabsKey.isEmpty {
                try? KeychainManager.shared.delete(.elevenLabs)
            } else {
                try KeychainManager.shared.update(elevenLabsKey, for: .elevenLabs)
            }

            if openRouterKey.isEmpty {
                try? KeychainManager.shared.delete(.openRouter)
            } else {
                try KeychainManager.shared.update(openRouterKey, for: .openRouter)
            }

            // 更新 AppState
            appState.apiKeyElevenLabs = elevenLabsKey.isEmpty ? nil : elevenLabsKey
            appState.apiKeyOpenRouter = openRouterKey.isEmpty ? nil : openRouterKey

            appState.log("Settings saved successfully")
            showSaveSuccess = true

            // 1.5秒后隐藏成功提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSaveSuccess = false
            }
        } catch {
            appState.log("Failed to save settings: \(error.localizedDescription)")
        }
    }
}

// ========================================
// MARK: - Preview
// ========================================

#Preview("Settings - API Keys") {
    let state = AppState()
    SettingsView()
        .environment(state)
}

#Preview("Settings - Style") {
    let state = AppState()
    SettingsView()
        .environment(state)
}
