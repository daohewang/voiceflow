/**
 * [INPUT]: 依赖 SwiftUI 框架，依赖 AppState
 * [OUTPUT]: 对外提供 MainWindow 视图，作为应用主界面
 * [POS]: VoiceFlow 的主窗口界面，提供角色选择和快捷操作入口
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI

// ========================================
// MARK: - Color Extensions
// ========================================

extension Color {
    /// 主题色
    static let themePrimary = Color(hex: "FF6B35")
    static let themeBackground = Color(hex: "F5F5F5")
    static let cardBackground = Color.white
    static let textPrimary = Color(hex: "212121")
    static let textSecondary = Color(hex: "757575")
    static let textTertiary = Color(hex: "BDBDBD")
    static let divider = Color(hex: "E0E0E0")
}

// ========================================
// MARK: - Main Window
// ========================================

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var selectedTab: MainTab = .home
    @State private var showSettings: Bool = false

    // ----------------------------------------
    // MARK: - Tabs
    // ----------------------------------------

    private enum MainTab: String, CaseIterable {
        case home = "首页"
        case roles = "人设"
        case history = "历史"

        var icon: String {
            switch self {
            case .home: return "house"
            case .roles: return "person.2"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }

    // ----------------------------------------
    // MARK: - Body
    // ----------------------------------------

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航栏
            sidebar
                .frame(minWidth: 160, idealWidth: 180, maxWidth: 200)

            // 分隔线
            Rectangle()
                .fill(Color.divider)
                .frame(width: 1)

            // 右侧主内容区
            mainContentArea
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(minWidth: 600, minHeight: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBackground)
    }

    // ----------------------------------------
    // MARK: - Sidebar
    // ----------------------------------------

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF6B35"), Color(hex: "FF8F65")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("VoiceFlow")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)

            // 导航菜单
            VStack(spacing: 4) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    sidebarItem(tab: tab)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // 底部操作
            VStack(spacing: 4) {
                sidebarButton(icon: "gearshape", title: "设置") {
                    showSettings = true
                }

                sidebarButton(icon: "questionmark.circle", title: "帮助") {
                    // 打开帮助
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environment(appState)
        }
    }

    private func sidebarItem(tab: MainTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                    .frame(width: 24)

                Text(tab.rawValue)
                    .font(.system(size: 14, design: .rounded))

                Spacer()
            }
            .foregroundColor(selectedTab == tab ? .themePrimary : .textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.themePrimary.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func sidebarButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 24)
                    .foregroundColor(.textSecondary)

                Text(title)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // ----------------------------------------
    // MARK: - Main Content Area
    // ----------------------------------------

    private var mainContentArea: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case .home:
                homeView
            case .roles:
                rolesView
            case .history:
                historyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ----------------------------------------
    // MARK: - Home View
    // ----------------------------------------

    private var homeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                welcomeSection.padding(.top, 20)
                statsSection
                currentRoleSection
                recentInputsSection.padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
    }

    private var welcomeSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(welcomeTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("按 \(appState.hotkeyConfig.displayString) 开始 · Esc 取消")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            Button { toggleRecording() } label: {
                ZStack {
                    Circle()
                        .fill(appState.currentStatus == .recording ? Color.red : Color.themePrimary)
                        .frame(width: 48, height: 48)
                        .shadow(
                            color: (appState.currentStatus == .recording ? Color.red : Color.themePrimary).opacity(0.35),
                            radius: 8, x: 0, y: 4
                        )
                    Image(systemName: appState.currentStatus == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    private var welcomeTitle: String {
        switch appState.currentStatus {
        case .idle:        return "语音输入"
        case .recording:   return "正在录音..."
        case .processing:  return "AI 润色中..."
        case .injecting:   return "注入文本..."
        case .error:       return "发生错误"
        }
    }

    private var statusMessage: String {
        switch appState.currentStatus {
        case .idle: return ""
        case .recording: return "正在录音，请说话..."
        case .processing: return "AI 正在润色文本..."
        case .injecting: return "文本已注入"
        case .error: return appState.errorMessage ?? "发生错误"
        }
    }

    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(value: "\(UsageStats.shared.totalRecordings)", label: "录音次数")
            statSeparator()
            statItem(value: "\(UsageStats.shared.totalCharactersTyped)", label: "口述字数")
            statSeparator()
            statItem(value: UsageStats.shared.formattedTimeSaved, label: "节省时间")
        }
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func statSeparator() -> some View {
        Rectangle()
            .fill(Color.divider)
            .frame(width: 1, height: 28)
    }

    private var currentRoleSection: some View {
        let template = StyleTemplate.predefinedTemplates.first(where: { $0.id == appState.selectedStyleId })
            ?? StyleTemplateStore.shared.customTemplates.first(where: { $0.id == appState.selectedStyleId })

        return Group {
            if let template = template {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(roleColor(for: template.id).opacity(0.12))
                            .frame(width: 36, height: 36)
                        Text(String(template.name.prefix(1)))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(roleColor(for: template.id))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前人设")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.textTertiary)
                        Text(template.name)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    Button { selectedTab = .roles } label: {
                        Text("更换")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.themePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .cornerRadius(14)
            }
        }
    }

    private var hotkeyTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)

            Text("快捷键：\(appState.hotkeyConfig.displayString) 开始/结束录音，Esc 取消")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.textTertiary)
        }
    }

    // ----------------------------------------
    // MARK: - Recent Inputs Section
    // ----------------------------------------

    @State private var copiedEntryId: UUID? = nil

    private var recentInputsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 节标题行
            HStack {
                Text("最近输入")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.textTertiary)
                Spacer()
                if !appState.historyEntries.isEmpty {
                    Button {
                        let all = appState.historyEntries.prefix(10).map { $0.finalText }.joined(separator: "\n\n")
                        copyToClipboard(all)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                            Text("全部复制")
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundColor(.themePrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            if appState.historyEntries.isEmpty {
                Text("语音输入后，文字将在此显示")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.cardBackground)
                    .cornerRadius(14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.historyEntries.prefix(10).enumerated()), id: \.element.id) { idx, entry in
                        recentInputRow(entry: entry)
                        if idx < min(appState.historyEntries.count, 10) - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color.cardBackground)
                .cornerRadius(14)
            }
        }
    }

    private func recentInputRow(entry: AppState.HistoryEntry) -> some View {
        HStack(spacing: 10) {
            Text(entry.finalText)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                copyToClipboard(entry.finalText)
                copiedEntryId = entry.id
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if copiedEntryId == entry.id { copiedEntryId = nil }
                }
            } label: {
                Image(systemName: copiedEntryId == entry.id ? "checkmark" : "doc.on.clipboard")
                    .font(.system(size: 13))
                    .foregroundColor(copiedEntryId == entry.id ? .themePrimary : .textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // ----------------------------------------
    // MARK: - Roles View
    // ----------------------------------------

    @State private var showTemplateEditor = false
    @State private var editingTemplate: StyleTemplate?
    @State private var showAddTemplate = false

    private var rolesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题栏
                HStack {
                    Text("人设模板")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        showAddTemplate = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加人设")
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.themePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                // 预设人设
                VStack(alignment: .leading, spacing: 8) {
                    Text("预设人设")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.textTertiary)
                        .padding(.horizontal, 24)

                    LazyVStack(spacing: 10) {
                        ForEach(StyleTemplateStore.shared.predefinedTemplateList, id: \.id) { template in
                            roleDetailCard(template: template)
                        }
                    }
                }

                // 自定义人设
                let customTemplates = StyleTemplateStore.shared.customTemplates
                if !customTemplates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("自定义人设")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.textTertiary)
                            .padding(.horizontal, 24)

                        LazyVStack(spacing: 10) {
                            ForEach(customTemplates, id: \.id) { template in
                                roleDetailCard(template: template, showEdit: true)
                            }
                        }
                    }
                }

                Spacer().frame(height: 24)
            }
        }
        .sheet(isPresented: $showAddTemplate) {
            TemplateEditorView(template: nil) { newTemplate in
                StyleTemplateStore.shared.addTemplate(newTemplate)
            }
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(template: template) { updated in
                StyleTemplateStore.shared.updateTemplate(updated)
            }
        }
    }

    private func roleDetailCard(template: StyleTemplate, showEdit: Bool = false) -> some View {
        Button {
            appState.selectedStyleId = template.id
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(roleColor(for: template.id).opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text(String(template.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(roleColor(for: template.id))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(template.name)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.textPrimary)

                        if template.isPredefined {
                            Text("预设")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.textTertiary))
                        }
                    }

                    Text(template.systemPrompt)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // 编辑按钮（仅自定义人设）
                if showEdit {
                    Button {
                        editingTemplate = template
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }

                if appState.selectedStyleId == template.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.themePrimary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.cardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(appState.selectedStyleId == template.id ? Color.themePrimary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func roleDetailCard(template: StyleTemplate) -> some View {
        Button {
            appState.selectedStyleId = template.id
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(roleColor(for: template.id).opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text(String(template.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(roleColor(for: template.id))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.textPrimary)

                    Text(template.systemPrompt)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if appState.selectedStyleId == template.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.themePrimary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.cardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(appState.selectedStyleId == template.id ? Color.themePrimary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // ----------------------------------------
    // MARK: - History View
    // ----------------------------------------

    private var historyView: some View {
        Group {
            if appState.historyEntries.isEmpty {
                emptyHistoryPlaceholder
            } else {
                historyList
            }
        }
    }

    private var emptyHistoryPlaceholder: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.textTertiary)
            Text("暂无历史记录")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
            Text("开始录音后，您的历史记录将显示在这里")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(appState.historyEntries) { entry in
                    historyCard(entry: entry)
                }
            }
            .padding(24)
        }
    }

    private func historyCard(entry: AppState.HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date, style: .relative)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.textTertiary)
                Spacer()
                Text("\(entry.durationSeconds) 秒")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.textTertiary)
            }

            Text(entry.finalText)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.textPrimary)
                .lineLimit(3)

            if entry.asrText != entry.finalText {
                Text("识别原文：\(entry.asrText)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    // ----------------------------------------
    // MARK: - Helpers
    // ----------------------------------------

    private func roleColor(for id: String) -> Color {
        let colors: [String: Color] = [
            "default": Color(hex: "FF6B35"),
            "formal": Color(hex: "3B82F6"),
            "casual": Color(hex: "10B981"),
            "concise": Color(hex: "F59E0B"),
            "expand": Color(hex: "EC4899"),
            "translate-en": Color(hex: "06B6D4"),
            "translate-zh": Color(hex: "EF4444"),
            "code-doc": Color(hex: "6366F1")
        ]
        return colors[id] ?? .themePrimary
    }

    private func toggleRecording() {
        switch appState.currentStatus {
        case .idle:
            appState.currentStatus = .recording
            appState.startNewSession()
            RecordingCoordinator.shared.startRecording()
        case .recording:
            RecordingCoordinator.shared.stopRecording()
        default:
            break
        }
    }
}

// ========================================
// MARK: - Settings Sheet
// ========================================

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedTab: SettingsTab = .apiKeys
    @State private var elevenLabsKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var showElevenLabsKey: Bool = false
    @State private var showOpenRouterKey: Bool = false
    @State private var isRecordingHotkey: Bool = false

    private enum SettingsTab: String, CaseIterable {
        case apiKeys = "API 配置"
        case hotkey = "快捷键"
        case about = "关于"

        var icon: String {
            switch self {
            case .apiKeys: return "key"
            case .hotkey: return "keyboard"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Text("设置")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.cardBackground)

            // Tab 栏
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 13, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTab == tab ? Color.themePrimary.opacity(0.1) : .clear)
                        .foregroundColor(selectedTab == tab ? .themePrimary : .textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.themeBackground)

            // 内容区
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .apiKeys:
                        apiKeysContent
                    case .hotkey:
                        hotkeyContent
                    case .about:
                        aboutContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 400)
        .background(Color.themeBackground)
        .onAppear {
            loadSettings()
        }
    }

    private var apiKeysContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ElevenLabs
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ElevenLabs API Key")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Link("获取密钥", destination: URL(string: "https://elevenlabs.io")!)
                        .font(.caption)
                        .foregroundColor(.themePrimary)
                }

                HStack {
                    if showElevenLabsKey {
                        TextField("sk-...", text: $elevenLabsKey)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                    } else {
                        SecureField("sk-...", text: $elevenLabsKey)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                    }

                    Button {
                        showElevenLabsKey.toggle()
                    } label: {
                        Image(systemName: showElevenLabsKey ? "eye.slash" : "eye")
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text("用于 ASR 语音识别服务")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }

            Divider()
                .background(Color.divider)

            // OpenRouter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("OpenRouter API Key")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Link("获取密钥", destination: URL(string: "https://openrouter.ai/keys")!)
                        .font(.caption)
                        .foregroundColor(.themePrimary)
                }

                HStack {
                    if showOpenRouterKey {
                        TextField("sk-or-...", text: $openRouterKey)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                    } else {
                        SecureField("sk-or-...", text: $openRouterKey)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                    }

                    Button {
                        showOpenRouterKey.toggle()
                    } label: {
                        Image(systemName: showOpenRouterKey ? "eye.slash" : "eye")
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text("用于 LLM 文本润色 (GPT-4o、Claude 等)")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            // 保存按钮
            Button {
                saveSettings()
                dismiss()
            } label: {
                Text("保存")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.themePrimary)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var hotkeyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("全局快捷键")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.textPrimary)

            HStack {
                Text("录音快捷键")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.textSecondary)

                Spacer()

                HotkeyRecorderView(
                    config: appState.hotkeyConfig,
                    isRecording: $isRecordingHotkey
                ) { newConfig in
                    Task { @MainActor in
                        appState.saveHotkeyConfig(newConfig)
                    }
                }
            }

            Text(isRecordingHotkey ? "按下新的快捷键组合..." : "点击上方按钮可以重新录制快捷键")
                .font(.caption2)
                .foregroundColor(isRecordingHotkey ? .themePrimary : .textTertiary)

            Spacer()
        }
    }

    private var aboutContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FF6B35"), Color(hex: "FF8F65")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("VoiceFlow")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)

            Text("版本 0.0.2")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.textTertiary)

            Text("语音输入，智能润色")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.textSecondary)

            Divider()
                .background(Color.divider)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/daohewang/voiceflow")!) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.themePrimary)
                        Text("GitHub 仓库")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }
                }

                Link(destination: URL(string: "https://github.com/daohewang/voiceflow/issues")!) {
                    HStack {
                        Image(systemName: "ladybug")
                            .foregroundColor(.themePrimary)
                        Text("反馈问题")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func loadSettings() {
        if let key = try? KeychainManager.shared.get(.elevenLabs), !key.isEmpty {
            elevenLabsKey = key
        }
        if let key = try? KeychainManager.shared.get(.openRouter), !key.isEmpty {
            openRouterKey = key
        }
    }

    private func saveSettings() {
        try? KeychainManager.shared.update(elevenLabsKey, for: .elevenLabs)
        try? KeychainManager.shared.update(openRouterKey, for: .openRouter)
    }
}

// ========================================
// MARK: - Preview
// ========================================

#Preview("Main Window") {
    MainWindow()
        .environment(AppState())
}
