/**
 * [INPUT]: 依赖 Foundation (URLSession)、LLMProvider 协议
 * [OUTPUT]: 对外提供 DeepSeekProvider 实现
 * [POS]: VoiceFlow 的 DeepSeek LLM 提供商实现
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation

// ========================================
// MARK: - DeepSeek Provider
// ========================================

struct DeepSeekProvider: LLMProvider {

    let type: LLMProviderType = .deepSeek
    let name = "DeepSeek"

    private let apiBaseURL = "https://api.deepseek.com/v1/chat/completions"
    private let model = "deepseek-chat"

    // ----------------------------------------
    // MARK: - LLMProvider Implementation
    // ----------------------------------------

    func polishText(
        _ text: String,
        systemPrompt: String,
        apiKey: String
    ) async throws -> String {
        print("[DeepSeekProvider] Starting request...")
        print("[DeepSeekProvider] API Key (first 10 chars): \(String(apiKey.prefix(10)))...")
        print("[DeepSeekProvider] Text: \(text)")

        guard !apiKey.isEmpty else {
            print("[DeepSeekProvider] ERROR: Missing API Key")
            throw LLMProviderError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: apiBaseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "stream": false,
            "temperature": 0.7,
            "max_tokens": 2000
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("[DeepSeekProvider] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DeepSeekProvider] ERROR: Invalid response type")
                throw LLMProviderError.invalidResponse
            }

            print("[DeepSeekProvider] Response status: \(httpResponse.statusCode)")
            print("[DeepSeekProvider] Response body: \(String(data: data, encoding: .utf8) ?? "nil")")

            guard httpResponse.statusCode == 200 else {
                // 尝试解析错误信息
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("[DeepSeekProvider] API Error: \(message)")
                    throw LLMProviderError.apiError(message)
                }
                throw LLMProviderError.apiError("HTTP \(httpResponse.statusCode)")
            }

            // 解析响应
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("[DeepSeekProvider] ERROR: Failed to decode response")
                throw LLMProviderError.decodingError
            }

            print("[DeepSeekProvider] Success! Content: \(content)")
            return content
        } catch {
            print("[DeepSeekProvider] ERROR: \(error.localizedDescription)")
            throw error
        }
    }
}
