import Foundation

/// Legacy development configuration - Redirects to AppConfiguration
/// This file is kept for backward compatibility
/// @available(*, deprecated, message: "Use AppConfiguration instead")
struct DevelopmentConfig {
    /// Cloudflare Worker URL
    static let workerURL = AppConfiguration.workerURL
    
    /// Development-only flag
    static let isDevelopment = AppConfiguration.isDevelopment
    
    /// Auto-create anonymous account on first launch
    static let autoCreateAccount = AppConfiguration.autoCreateAccount
    
    /// Pre-configured Groq API key for development
    /// WARNING: This returns a placeholder value. Configure via environment variables instead
    static let demoGroqAPIKey = AppConfiguration.demoAPIKey ?? "demo-api-key-not-configured"
    
    /// Enable automatic MCP connection
    static let autoConnectMCP = AppConfiguration.autoConnectMCP
}