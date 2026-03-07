/**
 * [INPUT]: 依赖 LLMProvider、ASRProvider 协议及其实现
 * [OUTPUT]: 对外提供 ProviderFactory，创建提供商实例
 * [POS]: VoiceFlow 的提供商工厂，支持运行时切换
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation

// ========================================
// MARK: - Provider Factory
// ========================================

@MainActor
struct ProviderFactory {

    // ----------------------------------------
    // MARK: - LLM Provider Factory
    // ----------------------------------------

    static func createLLMProvider(type: LLMProviderType) -> LLMProvider {
        switch type {
        case .openRouter:
            return OpenRouterProvider()
        case .deepSeek:
            return DeepSeekProvider()
        case .miniMax:
            // TODO: 实现 MiniMaxProvider
            return OpenRouterProvider() // Fallback
        case .zhiPu:
            // TODO: 实现 ZhiPuProvider
            return OpenRouterProvider() // Fallback
        case .kimi:
            // TODO: 实现 KimiProvider
            return OpenRouterProvider() // Fallback
        }
    }

    // ----------------------------------------
    // MARK: - ASR Provider Factory
    // ----------------------------------------

    static func createASRProvider(type: ASRProviderType) -> ASRProvider {
        switch type {
        case .elevenLabs:
            // ElevenLabs 使用现有 ASRClient 的逻辑
            fatalError("ElevenLabs provider will be handled by existing ASRClient")
        case .deepSeek:
            // TODO: 实现 DeepSeek ASR
            fatalError("DeepSeek ASR not yet implemented")
        case .openAI:
            // TODO: 实现 OpenAI ASR
            fatalError("OpenAI ASR not yet implemented")
        }
    }
}

// ========================================
// MARK: - Provider Config
// ========================================

struct ProviderConfig: Codable {
    var llmProvider: LLMProviderType = .openRouter
    var asrProvider: ASRProviderType = .elevenLabs

    static let `default` = ProviderConfig()
}
