import Foundation
import Combine

class LLMConfiguration: ObservableObject {
    static let shared = LLMConfiguration()
    
    @Published var selectedProvider: LLMProviderType = .cloudflare
    @Published var autoFallbackToLocal: Bool = true
    @Published var selectedLocalModel: String?
    
    private var cloudflareProvider = CloudflareProvider()
    private var localProvider: LocalLLMProvider
    
    enum LLMProviderType: String, CaseIterable {
        case cloudflare = "Cloudflare (Groq)"
        case local = "Local LLM"
        
        var icon: String {
            switch self {
            case .cloudflare: return "cloud.fill"
            case .local: return "desktopcomputer"
            }
        }
    }
    
    init() {
        self.localProvider = LocalLLMProvider()
        loadSettings()
    }
    
    var currentProvider: LLMProvider {
        switch selectedProvider {
        case .cloudflare:
            return cloudflareProvider
        case .local:
            return localProvider
        }
    }
    
    func complete(prompt: String, maxTokens: Int = 1000) async throws -> String {
        do {
            return try await currentProvider.complete(prompt: prompt, maxTokens: maxTokens)
        } catch let error as LLMError {
            switch error {
            case .rateLimitExceeded(_, let suggestion):
                if autoFallbackToLocal && localProvider.isAvailable {
                    // Notify about fallback with suggestion if available
                    var userInfo: [String: Any] = ["fallback": true]
                    if let suggestion = suggestion {
                        userInfo["suggestion"] = suggestion
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name("LLMFallbackToLocal"),
                        object: nil,
                        userInfo: userInfo
                    )
                    // Fallback to local LLM
                    return try await localProvider.complete(prompt: prompt, maxTokens: maxTokens)
                }
            case .notAvailable:
                if autoFallbackToLocal && localProvider.isAvailable {
                    // Notify about fallback with more context
                    NotificationCenter.default.post(
                        name: Notification.Name("LLMFallbackToLocal"),
                        object: nil,
                        userInfo: [
                            "fallback": true,
                            "reason": "Cloudflare provider not available",
                            "suggestion": "Configure your API key in Settings or wait for local LLM implementation"
                        ]
                    )
                    // Fallback to local LLM
                    return try await localProvider.complete(prompt: prompt, maxTokens: maxTokens)
                }
            default:
                break
            }
            throw error
        }
    }
    
    func stream(prompt: String, maxTokens: Int = 1000) async throws -> AsyncStream<String> {
        do {
            return try await currentProvider.stream(prompt: prompt, maxTokens: maxTokens)
        } catch let error as LLMError {
            switch error {
            case .rateLimitExceeded(_, let suggestion):
                if autoFallbackToLocal && localProvider.isAvailable {
                    // Notify about fallback with suggestion if available
                    var userInfo: [String: Any] = ["fallback": true]
                    if let suggestion = suggestion {
                        userInfo["suggestion"] = suggestion
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name("LLMFallbackToLocal"),
                        object: nil,
                        userInfo: userInfo
                    )
                    // Fallback to local LLM
                    return try await localProvider.stream(prompt: prompt, maxTokens: maxTokens)
                }
            case .notAvailable:
                if autoFallbackToLocal && localProvider.isAvailable {
                    // Notify about fallback with more context
                    NotificationCenter.default.post(
                        name: Notification.Name("LLMFallbackToLocal"),
                        object: nil,
                        userInfo: [
                            "fallback": true,
                            "reason": "Cloudflare provider not available",
                            "suggestion": "Configure your API key in Settings or wait for local LLM implementation"
                        ]
                    )
                    // Fallback to local LLM
                    return try await localProvider.stream(prompt: prompt, maxTokens: maxTokens)
                }
            default:
                break
            }
            throw error
        }
    }
    
    func selectLocalModel(_ modelId: String) {
        selectedLocalModel = modelId
        localProvider.selectModel(modelId)
        saveSettings()
    }
    
    private func loadSettings() {
        if let providerString = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = LLMProviderType(rawValue: providerString) {
            selectedProvider = provider
        }
        
        autoFallbackToLocal = UserDefaults.standard.bool(forKey: "autoFallbackToLocal")
        if autoFallbackToLocal == false {
            autoFallbackToLocal = true // Default to true
        }
        
        if let modelId = UserDefaults.standard.string(forKey: "selectedLocalModel") {
            selectedLocalModel = modelId
            localProvider.selectModel(modelId)
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        UserDefaults.standard.set(autoFallbackToLocal, forKey: "autoFallbackToLocal")
        UserDefaults.standard.set(selectedLocalModel, forKey: "selectedLocalModel")
    }
}