import Foundation

class CloudflareProvider: LLMProvider {
    let id = "cloudflare"
    let name = "Cloudflare Gateway (Groq)"
    var isAvailable: Bool {
        return AuthManager.shared.isAuthenticated
    }
    
    private let baseURL = DevelopmentConfig.workerURL
    private let model = "llama-3.3-70b-versatile" // Groq's fast model
    
    func complete(prompt: String, maxTokens: Int = 1000) async throws -> String {
        guard let apiKey = AuthManager.shared.apiKey else {
            throw LLMError.notAvailable
        }
        
        // Development mode: If using demo API key, return mock response
        if DevelopmentConfig.isDevelopment && apiKey.hasPrefix("demo-api-key-") {
            print("[CloudflareProvider] Using demo mode, returning mock response")
            return "I'm running in demo mode. To use real AI responses, please deploy the Cloudflare Worker and ensure it's accessible at: \(baseURL)"
        }
        
        let url = URL(string: "\(baseURL)/api/groq/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "stream": false
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Extract rate limit information
                if let limitStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Limit"),
                   let remainingStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
                   let limit = Int(limitStr),
                   let remaining = Int(remainingStr) {
                    // Store rate limit info
                    NotificationCenter.default.post(
                        name: Notification.Name("RateLimitUpdate"),
                        object: nil,
                        userInfo: ["limit": limit, "remaining": remaining]
                    )
                }
                
                if httpResponse.statusCode == 429 {
                    // Parse rate limit headers
                    var resetDate = Date().addingTimeInterval(3600) // Default 1 hour
                    
                    if let resetString = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset") {
                        if let date = ISO8601DateFormatter().date(from: resetString) {
                            resetDate = date
                        } else if let timestamp = Double(resetString) {
                            resetDate = Date(timeIntervalSince1970: timestamp)
                        }
                    }
                    
                    // Try to parse error response for more details
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let suggestion = errorJson["suggestion"] as? String {
                        throw LLMError.rateLimitExceeded(resetAt: resetDate, suggestion: suggestion)
                    }
                    
                    throw LLMError.rateLimitExceeded(resetAt: resetDate, suggestion: nil)
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw LLMError.invalidResponse
                }
            }
            
            let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
            guard let content = llmResponse.choices.first?.message.content else {
                throw LLMError.invalidResponse
            }
            
            return content
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }
    
    func stream(prompt: String, maxTokens: Int = 1000) async throws -> AsyncStream<String> {
        guard let apiKey = AuthManager.shared.apiKey else {
            throw LLMError.notAvailable
        }
        
        // Development mode: If using demo API key, return mock stream
        if DevelopmentConfig.isDevelopment && apiKey.hasPrefix("demo-api-key-") {
            print("[CloudflareProvider] Using demo mode, returning mock stream")
            return AsyncStream { continuation in
                let mockResponse = "I'm running in demo mode. To use real AI responses, please deploy the Cloudflare Worker at: \(baseURL)"
                for char in mockResponse {
                    continuation.yield(String(char))
                }
                continuation.finish()
            }
        }
        
        return AsyncStream { continuation in
            Task {
                let url = URL(string: "\(baseURL)/api/groq/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                
                let body = [
                    "model": model,
                    "messages": [
                        ["role": "user", "content": prompt]
                    ],
                    "max_tokens": maxTokens,
                    "stream": true
                ] as [String : Any]
                
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 429 {
                        continuation.finish()
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                break
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let delta = choices.first?["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                continuation.yield(content)
                            }
                        }
                    }
                } catch {
                    continuation.finish()
                }
            }
        }
    }
}