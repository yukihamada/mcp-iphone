import Foundation

/// Application configuration management
struct AppConfiguration {
    /// Current environment
    static var environment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    /// Environment types
    enum Environment {
        case development
        case production
    }
    
    /// Cloudflare Worker URL
    static var workerURL: String {
        switch environment {
        case .development:
            return "https://mcp-iphone-gateway.yukihamada.workers.dev"
        case .production:
            return "https://mcp-iphone-gateway.yukihamada.workers.dev" // Same for now
        }
    }
    
    /// Auto-create anonymous account on first launch
    static var autoCreateAccount: Bool {
        switch environment {
        case .development:
            return true
        case .production:
            return true // Enable for better UX
        }
    }
    
    /// Enable automatic MCP connection
    static var autoConnectMCP: Bool {
        switch environment {
        case .development:
            return true
        case .production:
            return false // Let users manually connect in production
        }
    }
    
    /// Demo API key (development only)
    static var demoAPIKey: String? {
        switch environment {
        case .development:
            // Only return a demo key if explicitly set in environment
            return ProcessInfo.processInfo.environment["DEMO_API_KEY"]
        case .production:
            return nil
        }
    }
    
    /// Check if running in development mode
    static var isDevelopment: Bool {
        return environment == .development
    }
    
    /// Log configuration on app launch
    static func logConfiguration() {
        print("[AppConfiguration] Environment: \(environment)")
        print("[AppConfiguration] Worker URL: \(workerURL)")
        print("[AppConfiguration] Auto-create account: \(autoCreateAccount)")
        print("[AppConfiguration] Auto-connect MCP: \(autoConnectMCP)")
        print("[AppConfiguration] Has demo API key: \(demoAPIKey != nil)")
    }
}

// MARK: - Legacy Support

/// Legacy development configuration wrapper
/// Maintains backward compatibility while transitioning to AppConfiguration
struct DevelopmentConfig {
    static let workerURL = AppConfiguration.workerURL
    static let isDevelopment = AppConfiguration.isDevelopment
    static let autoCreateAccount = AppConfiguration.autoCreateAccount
    static let autoConnectMCP = AppConfiguration.autoConnectMCP
    
    /// Demo API key - now returns a placeholder to avoid crashes
    /// Apps should handle missing API keys gracefully
    static var demoGroqAPIKey: String {
        return AppConfiguration.demoAPIKey ?? "demo-api-key-not-configured"
    }
}