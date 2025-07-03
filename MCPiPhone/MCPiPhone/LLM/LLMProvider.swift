import Foundation

protocol LLMProvider {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get }
    
    func complete(prompt: String, maxTokens: Int) async throws -> String
    func stream(prompt: String, maxTokens: Int) async throws -> AsyncStream<String>
}

enum LLMError: LocalizedError {
    case notAvailable
    case networkError(Error)
    case rateLimitExceeded(resetAt: Date)
    case invalidResponse
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "LLM provider is not available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded(let resetAt):
            return "Rate limit exceeded. Try again at \(resetAt)"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .modelNotFound:
            return "Model not found or not downloaded"
        }
    }
}

struct LLMResponse: Codable {
    let id: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}