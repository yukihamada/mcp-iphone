import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    
    private let llmConfig = LLMConfiguration.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Add a welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: """
            Hello! I'm your AI assistant with MCP (Model Context Protocol) integration.
            
            I can help you with:
            • General questions and conversations
            • Analyzing output from MCP tools
            • Understanding device information and system status
            
            Use the MCP Tools tab to:
            • Get device info (battery, system, storage)
            • Access photos and files
            • Search the web and music
            • And more!
            
            How can I assist you today?
            """
        ))
        
        // Listen for rate limit updates
        NotificationCenter.default.publisher(for: Notification.Name("RateLimitUpdate"))
            .sink { [weak self] notification in
                if let limit = notification.userInfo?["limit"] as? Int,
                   let remaining = notification.userInfo?["remaining"] as? Int {
                    self?.statusMessage = "API calls: \(remaining)/\(limit) remaining"
                }
            }
            .store(in: &cancellables)
        
        // Listen for fallback notifications
        NotificationCenter.default.publisher(for: Notification.Name("LLMFallbackToLocal"))
            .sink { [weak self] notification in
                var message = "Switched to local LLM due to rate limit"
                if let suggestion = notification.userInfo?["suggestion"] as? String {
                    message += ". \(suggestion)"
                }
                self?.statusMessage = message
            }
            .store(in: &cancellables)
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        
        // Clear any previous error
        errorMessage = nil
        isLoading = true
        
        do {
            // Check if current provider is available
            guard llmConfig.currentProvider.isAvailable else {
                throw LLMError.notAvailable
            }
            
            // Build the prompt with conversation history
            let prompt = buildPrompt()
            
            // Create a placeholder for the assistant's response
            let assistantMessage = ChatMessage(role: .assistant, content: "")
            messages.append(assistantMessage)
            let messageIndex = messages.count - 1
            
            // Get streaming response using LLMConfiguration (handles fallback)
            let stream = try await llmConfig.stream(prompt: prompt, maxTokens: 1000)
            
            var fullResponse = ""
            for await chunk in stream {
                fullResponse += chunk
                // Update the message with accumulated response
                messages[messageIndex] = ChatMessage(role: .assistant, content: fullResponse)
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            
            // Remove the empty assistant message if there was an error
            if messages.last?.content.isEmpty == true {
                messages.removeLast()
            }
            
            // Handle specific errors
            if let llmError = error as? LLMError {
                switch llmError {
                case .notAvailable:
                    errorMessage = "Please configure your API key in Settings"
                case .rateLimitExceeded(let resetAt, let suggestion):
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    var message = "Rate limit exceeded. Try again at \(formatter.string(from: resetAt))"
                    if let suggestion = suggestion {
                        message += ". \(suggestion)"
                    }
                    errorMessage = message
                default:
                    errorMessage = llmError.localizedDescription
                }
            } else {
                errorMessage = "An error occurred: \(error.localizedDescription)"
            }
        }
    }
    
    func clearMessages() {
        messages = [ChatMessage(
            role: .assistant,
            content: """
            Hello! I'm your AI assistant with MCP (Model Context Protocol) integration.
            
            I can help you with:
            • General questions and conversations
            • Analyzing output from MCP tools
            • Understanding device information and system status
            
            Use the MCP Tools tab to:
            • Get device info (battery, system, storage)
            • Access photos and files
            • Search the web and music
            • And more!
            
            How can I assist you today?
            """
        )]
        errorMessage = nil
    }
    
    private func buildPrompt() -> String {
        // Build a prompt that includes recent conversation history
        // Limit to last 10 messages to avoid token limits
        let recentMessages = messages.suffix(10)
        
        var prompt = ""
        for message in recentMessages {
            switch message.role {
            case .user:
                prompt += "User: \(message.content)\n"
            case .assistant:
                prompt += "Assistant: \(message.content)\n"
            case .system:
                prompt += "System: \(message.content)\n"
            }
        }
        
        // Remove the last newline
        if prompt.hasSuffix("\n") {
            prompt.removeLast()
        }
        
        return prompt
    }
}