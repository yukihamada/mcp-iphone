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
            case .rateLimitExceeded, .notAvailable:
                if autoFallbackToLocal && localProvider.isAvailable {
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
            case .rateLimitExceeded, .notAvailable:
                if autoFallbackToLocal && localProvider.isAvailable {
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