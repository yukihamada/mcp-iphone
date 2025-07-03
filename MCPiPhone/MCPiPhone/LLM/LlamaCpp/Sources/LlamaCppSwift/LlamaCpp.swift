import Foundation
import LlamaCppBridge

/// Swift wrapper for llama.cpp functionality
public class LlamaCpp {
    private let context: LLMContext
    
    /// Model configuration
    public struct Configuration {
        public let modelPath: String
        public let contextSize: Int
        public let threads: Int
        
        public init(modelPath: String, contextSize: Int = 2048, threads: Int = 4) {
            self.modelPath = modelPath
            self.contextSize = contextSize
            self.threads = threads
        }
    }
    
    /// Generation parameters
    public struct GenerationParams {
        public let maxTokens: Int
        public let temperature: Float
        public let topP: Float
        public let topK: Int
        public let repeatPenalty: Float
        
        public init(
            maxTokens: Int = 512,
            temperature: Float = 0.7,
            topP: Float = 0.9,
            topK: Int = 40,
            repeatPenalty: Float = 1.1
        ) {
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.topP = topP
            self.topK = topK
            self.repeatPenalty = repeatPenalty
        }
    }
    
    /// Initialize with configuration
    public init(configuration: Configuration) throws {
        guard let ctx = LLMContext(
            modelPath: configuration.modelPath,
            contextSize: configuration.contextSize,
            nThreads: configuration.threads
        ) else {
            throw LlamaCppError.initializationFailed
        }
        self.context = ctx
    }
    
    /// Generate text from prompt
    public func generate(prompt: String, params: GenerationParams = GenerationParams()) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LlamaCppError.contextReleased)
                    return
                }
                
                if let result = self.context.generate(
                    withPrompt: prompt,
                    maxTokens: params.maxTokens,
                    temperature: params.temperature,
                    topP: params.topP,
                    topK: params.topK,
                    repeatPenalty: params.repeatPenalty
                ) {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: LlamaCppError.generationFailed)
                }
            }
        }
    }
    
    /// Stream text generation
    public func stream(prompt: String, params: GenerationParams = GenerationParams()) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            context.streamGenerate(
                withPrompt: prompt,
                maxTokens: params.maxTokens,
                temperature: params.temperature,
                topP: params.topP,
                topK: params.topK,
                repeatPenalty: params.repeatPenalty
            ) { token, isComplete in
                if let token = token {
                    continuation.yield(token)
                }
                if isComplete {
                    continuation.finish()
                }
            }
        }
    }
    
    /// Get model information
    public var modelName: String {
        return context.modelName
    }
    
    public var contextLength: Int {
        return context.contextLength
    }
    
    /// Clear context
    public func clearContext() {
        context.clearContext()
    }
}

/// LlamaCpp errors
public enum LlamaCppError: LocalizedError {
    case initializationFailed
    case generationFailed
    case contextReleased
    case modelNotFound
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize llama.cpp context"
        case .generationFailed:
            return "Failed to generate text"
        case .contextReleased:
            return "Context has been released"
        case .modelNotFound:
            return "Model file not found"
        }
    }
}