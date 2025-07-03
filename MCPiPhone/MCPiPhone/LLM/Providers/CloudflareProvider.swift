import Foundation

class CloudflareProvider: LLMProvider {
    let id = "cloudflare"
    let name = "Cloudflare Gateway (Groq)"
    var isAvailable: Bool {
        return AuthManager.shared.isAuthenticated
    }
    
    private let baseURL = "https://mcp-iphone-gateway.workers.dev"
    private let model = "llama-3.3-70b-versatile" // Groq's fast model
    
    func complete(prompt: String, maxTokens: Int = 1000) async throws -> String {
        guard let apiKey = AuthManager.shared.apiKey else {
            throw LLMError.notAvailable
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
                if httpResponse.statusCode == 429 {
                    // Parse rate limit headers
                    if let resetString = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
                       let resetDate = ISO8601DateFormatter().date(from: resetString) {
                        throw LLMError.rateLimitExceeded(resetAt: resetDate)
                    } else {
                        throw LLMError.rateLimitExceeded(resetAt: Date().addingTimeInterval(3600))
                    }
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