import Foundation
import SwiftUI

/// Integration layer between MCP tools and LLM functionality
@MainActor
class MCPLLMIntegration: ObservableObject {
    static let shared = MCPLLMIntegration()
    
    private let llmConfig = LLMConfiguration.shared
    
    /// Generate an AI analysis of MCP tool output
    func analyzeToolOutput(toolName: String, output: String) async throws -> String {
        let prompt = """
        You are an AI assistant helping to analyze MCP tool output.
        
        Tool: \(toolName)
        Output:
        \(output)
        
        Please provide a helpful analysis of this output, explaining:
        1. What the output shows
        2. Any important information or insights
        3. Potential actions or recommendations based on the output
        
        Keep your response concise and user-friendly.
        """
        
        return try await llmConfig.complete(prompt: prompt, maxTokens: 500)
    }
    
    /// Generate suggestions for using MCP tools
    func suggestToolUsage(availableTools: [String]) async throws -> String {
        let toolsList = availableTools.joined(separator: ", ")
        
        let prompt = """
        You are an AI assistant helping users understand MCP tools.
        
        Available tools: \(toolsList)
        
        Please suggest interesting ways to use these tools, including:
        1. What each tool does
        2. Practical use cases
        3. How tools might work together
        
        Keep your response helpful and encouraging.
        """
        
        return try await llmConfig.complete(prompt: prompt, maxTokens: 500)
    }
    
    /// Create a chat message from tool output
    func createToolOutputMessage(toolName: String, output: String) -> String {
        return """
        MCP Tool Result - \(toolName):
        
        \(output)
        
        Would you like me to analyze this output or help you understand what it means?
        """
    }
}

/// Extension to add MCP integration to Chat
extension ChatViewModel {
    /// Add MCP tool result to chat
    func addToolResult(toolName: String, output: String) {
        let message = MCPLLMIntegration.shared.createToolOutputMessage(
            toolName: toolName,
            output: output
        )
        
        messages.append(ChatMessage(
            role: .system,
            content: message
        ))
    }
    
    /// Ask AI to analyze tool output
    func analyzeToolOutput(toolName: String, output: String) async {
        // Add user's request
        messages.append(ChatMessage(
            role: .user,
            content: "Please analyze the \(toolName) output for me."
        ))
        
        isLoading = true
        errorMessage = nil
        
        do {
            let analysis = try await MCPLLMIntegration.shared.analyzeToolOutput(
                toolName: toolName,
                output: output
            )
            
            messages.append(ChatMessage(
                role: .assistant,
                content: analysis
            ))
        } catch {
            errorMessage = "Failed to analyze tool output: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}