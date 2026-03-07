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

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(isEditing ? "编辑人设" : "新建人设")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 表单
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 名称
                    VStack(alignment: .leading, spacing: 6) {
                        Text("名称")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("例如：正式风格", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 系统提示词
                    VStack(alignment: .leading, spacing: 6) {
                        Text("系统提示词")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 120)
                            .padding(4)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )

                        Text("描述 AI 如何处理您的语音输入")
                            .font(.system(size: 10))
                            .foregroundColor(Color.textTertiary)
                    }

                    // 温度滑块
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("创造性")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(String(format: "%.1f", temperature))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $temperature, in: 0...1, step: 0.1)

                        HStack {
                            Text("保守")
                                .font(.system(size: 10))
                                .foregroundColor(Color.textTertiary)
                            Spacer()
                            Text("创造")
                                .font(.system(size: 10))
                                .foregroundColor(Color.textTertiary)
                        }
                    }

                    // 最大字数
                    VStack(alignment: .leading, spacing: 6) {
                        Text("最大输出字数")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach([300, 500, 800, 1000], id: \.self) { value in
                                Button {
                                    maxTokens = value
                                } label: {
                                    Text("\(value)")
                                        .font(.system(size: 12, design: .rounded))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(maxTokens == value ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                                        .foregroundColor(maxTokens == value ? .white : .primary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // 底部按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("保存") {
                    saveTemplate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || systemPrompt.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .onAppear {
            if let template = template {
                name = template.name
                systemPrompt = template.systemPrompt
                temperature = template.temperature
                maxTokens = template.maxTokens
            }
        }
    }

    private func saveTemplate() {
        let newTemplate: StyleTemplate
        if let existing = template {
            // 更新现有模板 - 创建新的副本
            newTemplate = StyleTemplate(
                id: existing.id,
                name: name,
                systemPrompt: systemPrompt,
                temperature: temperature,
                maxTokens: maxTokens,
                isPredefined: existing.isPredefined
            )
        } else {
            // 创建新模板
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
        name: "正式风格",
        systemPrompt: "你是一个专业的文字编辑，请将输入转换为正式的商务写作风格。",
        temperature: 0.7,
        maxTokens: 500,
        isPredefined: false
    )
    TemplateEditorView(template: template) { _ in }
}
