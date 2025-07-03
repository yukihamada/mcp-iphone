import Foundation
import Security

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var apiKey: String?
    @Published var isAuthenticated: Bool = false
    @Published var userTier: UserTier = .anonymous
    @Published var rateLimit: RateLimit?
    
    private let keychain = KeychainService()
    private let baseURL = DevelopmentConfig.workerURL
    
    enum UserTier: String, Codable {
        case anonymous
        case free
        case pro
    }
    
    struct RateLimit: Codable {
        let requests: Int
        let period: Int
        let remaining: Int?
        let resetAt: Date?
    }
    
    struct AuthResponse: Codable {
        let apiKey: String
        let token: String
        let tier: String
        let rateLimit: RateLimit
    }
    
    init() {
        loadStoredCredentials()
    }
    
    private func loadStoredCredentials() {
        if let apiKey = keychain.getString("apiKey") {
            self.apiKey = apiKey
            self.isAuthenticated = true
            
            if let tierString = keychain.getString("userTier"),
               let tier = UserTier(rawValue: tierString) {
                self.userTier = tier
            }
        } else if DevelopmentConfig.isDevelopment && DevelopmentConfig.autoCreateAccount {
            // In development, auto-create account if not exists
            print("[AuthManager] No stored credentials found, creating anonymous account...")
            Task {
                do {
                    try await createAnonymousAccount()
                } catch {
                    print("[AuthManager] Auto-create anonymous account failed: \(error)")
                    // Fallback to demo mode for development
                    await MainActor.run {
                        self.apiKey = DevelopmentConfig.demoAPIKey
                        self.userTier = .anonymous
                        self.isAuthenticated = true
                        print("[AuthManager] Using demo API key for development")
                    }
                }
            }
        }
    }
    
    func createAnonymousAccount() async throws {
        let url = URL(string: "\(baseURL)/api/auth/anonymous")!
        print("[AuthManager] Creating anonymous account at: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[AuthManager] Invalid response type")
                throw AuthError.requestFailed
            }
            
            print("[AuthManager] Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("[AuthManager] Error response: \(errorString)")
                }
                throw AuthError.requestFailed
            }
        
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            print("[AuthManager] Successfully created anonymous account")
            
            await MainActor.run {
                self.apiKey = authResponse.apiKey
                self.userTier = UserTier(rawValue: authResponse.tier) ?? .anonymous
                self.rateLimit = authResponse.rateLimit
                self.isAuthenticated = true
                
                try? keychain.setString(authResponse.apiKey, forKey: "apiKey")
                try? keychain.setString(authResponse.token, forKey: "token")
                try? keychain.setString(authResponse.tier, forKey: "userTier")
            }
        } catch {
            print("[AuthManager] Failed to create anonymous account: \(error)")
            throw error
        }
    }
    
    func registerWithEmail(_ email: String) async throws {
        let url = URL(string: "\(baseURL)/api/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.requestFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        await MainActor.run {
            self.apiKey = authResponse.apiKey
            self.userTier = UserTier(rawValue: authResponse.tier) ?? .free
            self.rateLimit = authResponse.rateLimit
            self.isAuthenticated = true
            
            try? keychain.setString(authResponse.apiKey, forKey: "apiKey")
            try? keychain.setString(authResponse.token, forKey: "token")
            try? keychain.setString(authResponse.tier, forKey: "userTier")
        }
    }
    
    func logout() {
        apiKey = nil
        isAuthenticated = false
        userTier = .anonymous
        rateLimit = nil
        
        try? keychain.deleteItem(forKey: "apiKey")
        try? keychain.deleteItem(forKey: "token")
        try? keychain.deleteItem(forKey: "userTier")
    }
}

enum AuthError: LocalizedError {
    case requestFailed
    case invalidEmail
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Authentication request failed"
        case .invalidEmail:
            return "Invalid email address"
        }
    }
}