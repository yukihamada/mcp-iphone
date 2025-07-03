import Foundation

/// Development configuration - DO NOT USE IN PRODUCTION
struct DevelopmentConfig {
    /// Cloudflare Worker URL
    static let workerURL = "https://mcp-iphone-gateway.workers.dev"
    
    /// Development-only flag
    static let isDevelopment = true
    
    /// Auto-create anonymous account on first launch
    static let autoCreateAccount = true
    
    /// Pre-configured Groq API key for development
    /// WARNING: This should only be used for development/demo purposes
    /// In production, users should generate their own API keys
    static let demoGroqAPIKey = "YOUR_GROQ_API_KEY_HERE"
    
    /// Enable automatic MCP connection
    static let autoConnectMCP = true
}

// MARK: - Production Warning
#if DEBUG
// Development configuration is enabled
#else
#warning("Development configuration should not be used in production builds")
#endif