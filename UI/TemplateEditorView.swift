/**
 * [INPUT]: 依赖 SwiftUI 框架、StyleTemplate 模型、StyleTemplateStore
 * [OUTPUT]: 对外提供 TemplateEditorView 视图，用于添加/编辑人设模板
 * [POS]: VoiceFlow 的模板编辑界面，被 MainWindow 调用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI

// ========================================
// MARK: - Template Editor View
// ========================================

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let template: StyleTemplate?
    let onSave: (StyleTemplate) -> Void

    @State private var name: String = ""
    @State private var systemPrompt: String = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 500

    private var isEditing: Bool { template != nil }

    // ----------------------------------------
    // MARK: - Body
    // ----------------------------------------

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            sheetHeader

            Divider()

            // 表单内容
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // 基本信息
                    basicInfoSection

                    // 系统提示词
                    promptSection

                    // 参数设置
                    parametersSection
                }
                .padding(28)
            }

            Divider()

            // 底部按钮
            footerButtons
        }
        .frame(width: 560, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadTemplate()
        }
    }

    // ----------------------------------------
    // MARK: - Header
    // ----------------------------------------

    private var sheetHeader: some View {
        HStack {
            Text(isEditing ? "编辑人设" : "新建人设")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }

    // ----------------------------------------
    // MARK: - Basic Info Section
    // ----------------------------------------

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "基本信息")

            VStack(alignment: .leading, spacing: 8) {
                Text("人设名称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                TextField("例如：羊羊风、正式商务", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)

                Text("给人设起一个容易记住的名字")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // ----------------------------------------
    // MARK: - Prompt Section
    // ----------------------------------------

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("系统提示词")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text("定义 AI 如何处理您的语音输入")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $systemPrompt)
                .font(.system(size: 13))
                .frame(minHeight: 180)
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

            // 提示示例
            VStack(alignment: .leading, spacing: 8) {
                Text("提示词示例")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    promptTip("明确任务", "你的任务是润色文本，不是回答问题")
                    promptTip("输出要求", "输出只包含润色后的文本")
                    promptTip("风格定义", "用轻松友好的语气复述")
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    private func promptTip(_ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // ----------------------------------------
    // MARK: - Parameters Section
    // ----------------------------------------

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "参数设置")

            // 创造性滑块
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("创造性")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("控制输出的创意程度")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text(String(format: "%.1f", temperature))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 36)
                }

                Slider(value: $temperature, in: 0...1, step: 0.1)
                    .controlSize(.regular)

                HStack {
                    Text("保守 · 稳定输出")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("创意 · 多样输出")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // 最大字数
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("最大输出字数")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("限制 AI 返回的文本长度")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 10) {
                    ForEach([300, 500, 800, 1000], id: \.self) { value in
                        Button {
                            maxTokens = value
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(maxTokens == value ? Color.accentColor : Color.clear)
                                )
                                .foregroundStyle(maxTokens == value ? .white : .primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(maxTokens == value ? Color.clear : Color(nsColor: .separatorColor), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    // ----------------------------------------
    // MARK: - Section Header
    // ----------------------------------------

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // ----------------------------------------
    // MARK: - Footer Buttons
    // ----------------------------------------

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button("保存") {
                saveTemplate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.isEmpty || systemPrompt.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // ----------------------------------------
    // MARK: - Actions
    // ----------------------------------------

    private func loadTemplate() {
        if let template = template {
            name = template.name
            systemPrompt = template.systemPrompt
            temperature = template.temperature
            maxTokens = template.maxTokens
        }
    }

    private func saveTemplate() {
        let newTemplate: StyleTemplate
        if let existing = template {
            newTemplate = StyleTemplate(
                id: existing.id,
                name: name,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
                isPredefined: existing.isPredefined
            )
        } else {
            newTemplate = StyleTemplate(
                name: name,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
                isPredefined: false
            )
        }

        onSave(newTemplate)
        dismiss()
    }
}

// ========================================
// MARK: - Preview
// ========================================

#Preview("New Template") {
    TemplateEditorView(template: nil) { _ in }
}

#Preview("Edit Template") {
    let template = StyleTemplate(
        name: "羊羊风",
        systemPrompt: "你是一个会用活泼可爱风格复述文字的助手。\n\n每次回复前先说：哈哈，笑死\n\n你的任务：将用户的口语化语音输入改写为流畅的书面语，保持原意不变。\n重要：不要回答用户的问题，只需要润色并复述用户说的话。\n输出只包含润色后的文本，不要有任何解释或建议。",
        temperature: 0.7,
        maxTokens: 500,
        isPredefined: false
    )
    TemplateEditorView(template: template) { _ in }
}
