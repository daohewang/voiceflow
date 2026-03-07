/**
 * [INPUT]: 依赖 Foundation (URLSession)、AppState 全局状态
 * [OUTPUT]: 对外提供 LLMClient 单例，支持流式文本润色和取消操作
 * [POS]: VoiceFlow 的 LLM 中枢，被录音流程调用进行文本润色
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation

// ========================================
// MARK: - LLM Client
// ========================================

@MainActor
@Observable
final class LLMClient {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = LLMClient()

    // ----------------------------------------
    // MARK: - Configuration
    // ----------------------------------------

    private let apiBaseURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "openai/gpt-4o"  // OpenRouter model ID

    // ----------------------------------------
    // MARK: - State
    // ----------------------------------------

    private(set) var isStreaming: Bool = false
    private var currentTask: URLSessionDataTask?
    private var accumulatedText: String = ""

    // ----------------------------------------
    // MARK: - Callbacks
    // ----------------------------------------

    /// 流式文本更新回调
    var onTextUpdate: ((String) -> Void)?

    /// 完成回调
    var onComplete: ((String) -> Void)?

    /// 错误回调
    var onError: ((Error) -> Void)?

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private init() {}

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 流式润色文本（使用提供商系统）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - style: 风格模板 ID
    ///   - apiKey: API Key
    ///   - providerType: LLM 提供商类型
    func polishText(_ text: String, style: String, apiKey: String, providerType: LLMProviderType = .openRouter) {
        guard !isStreaming else { return }
        guard !apiKey.isEmpty else {
            onError?(LLMError.missingAPIKey)
            return
        }

        isStreaming = true
        accumulatedText = ""

        let systemPrompt = buildSystemPrompt(for: style)
        let logMsg = """
        ========== LLM Request ==========
        [Provider]: \(providerType.displayName)
        [Template ID]: \(style)
        [User Text]: \(text)
        [System Prompt]:
        \(systemPrompt)
        =================================

        """
        Logger.shared.log(logMsg)

        // 使用提供商工厂创建提供商
        let provider = ProviderFactory.createLLMProvider(type: providerType)

        // 异步调用
        Task { @MainActor [weak self] in
            do {
                let result = try await provider.polishText(text, systemPrompt: systemPrompt, apiKey: apiKey)
                self?.accumulatedText = result
                self?.onComplete?(result)
                self?.isStreaming = false
            } catch {
                self?.onError?(error)
                self?.isStreaming = false
            }
        }
    }

    /// 流式润色文本（旧接口，保持兼容）
    func polishText(_ text: String, style: String, apiKey: String) {
        polishText(text, style: style, apiKey: apiKey, providerType: .openRouter)
    }

    /// 取消当前请求
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
        accumulatedText = ""
    }

    /// 根据模板 ID 构建系统提示词
    /// 优先从 StyleTemplateStore 读取用户自定义模板，fallback 到默认润色
    private func buildSystemPrompt(for templateId: String) -> String {
        // 从 Store 查找模板（包含预定义 + 自定义）
        if let template = StyleTemplateStore.shared.template(byId: templateId) {
            return template.systemPrompt
        }

        // Fallback: 使用默认润色模板
        let defaultPrompt = StyleTemplate.predefinedTemplates
            .first { $0.id == "default" }?
            .systemPrompt
            ?? "你是一个专业的文字润色助手。请将用户输入的口语化文本改写为更加流畅、专业的书面语，保持原意不变。输出只包含润色后的文本，不要有任何解释。"

        return defaultPrompt
    }

    // ----------------------------------------
    // MARK: - Response Handling
    // ----------------------------------------

    private nonisolated func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.isStreaming = false
                if (error as NSError).code != NSURLErrorCancelled {
                    self.onError?(LLMError.networkError(error))
                }
            }
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Task { @MainActor in
                self.isStreaming = false
                self.onError?(LLMError.invalidResponse)
            }
            return
        }

        guard httpResponse.statusCode == 200 else {
            Task { @MainActor in
                self.isStreaming = false
                let message = "HTTP \(httpResponse.statusCode)"
                self.onError?(LLMError.apiError(message))
            }
            return
        }

        guard let data = data else {
            Task { @MainActor in
                self.isStreaming = false
                self.onError?(LLMError.noData)
            }
            return
        }

        // 解析 SSE 响应
        parseSSEResponse(data)
    }

    /// 解析 SSE (Server-Sent Events) 响应
    private nonisolated func parseSSEResponse(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            Task { @MainActor in
                self.isStreaming = false
                self.onError?(LLMError.decodingError)
            }
            return
        }

        let lines = text.components(separatedBy: "\n")

        for line in lines {
            // SSE 格式: "data: {json}" 或 "data: [DONE]"
            guard line.hasPrefix("data: ") else { continue }

            let jsonStr = String(line.dropFirst(6))

            // 检查是否结束
            if jsonStr == "[DONE]" {
                Task { @MainActor in
                    self.isStreaming = false
                    self.onComplete?(self.accumulatedText)
                }
                return
            }

            // 解析 JSON
            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            Task { @MainActor in
                self.accumulatedText += content
                self.onTextUpdate?(self.accumulatedText)
            }
        }
    }
}

// ========================================
// MARK: - LLM Error
// ========================================

enum LLMError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case noData
    case decodingError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未配置 OpenRouter API Key"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .noData:
            return "无返回数据"
        case .decodingError:
            return "数据解析失败"
        }
    }
}
