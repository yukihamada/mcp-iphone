import Foundation
import Security

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var apiKey: String?
    @Published var isAuthenticated: Bool = false
    @Published var userTier: UserTier = .anonymous
    @Published var rateLimit: RateLimit?
    
    private let keychain = KeychainService()
    private let baseURL = "https://mcp-iphone-gateway.workers.dev" // Replace with your worker URL
    
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
        }
    }
    
    func createAnonymousAccount() async throws {
        let url = URL(string: "\(baseURL)/api/auth/anonymous")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.requestFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        await MainActor.run {
            self.apiKey = authResponse.apiKey
            self.userTier = UserTier(rawValue: authResponse.tier) ?? .anonymous
            self.rateLimit = authResponse.rateLimit
            self.isAuthenticated = true
            
            keychain.setString(authResponse.apiKey, forKey: "apiKey")
            keychain.setString(authResponse.token, forKey: "token")
            keychain.setString(authResponse.tier, forKey: "userTier")
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
            
            keychain.setString(authResponse.apiKey, forKey: "apiKey")
            keychain.setString(authResponse.token, forKey: "token")
            keychain.setString(authResponse.tier, forKey: "userTier")
        }
    }
    
    func logout() {
        apiKey = nil
        isAuthenticated = false
        userTier = .anonymous
        rateLimit = nil
        
        keychain.deleteItem(forKey: "apiKey")
        keychain.deleteItem(forKey: "token")
        keychain.deleteItem(forKey: "userTier")
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

class KeychainService {
    func setString(_ string: String, forKey key: String) {
        let data = string.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getString(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func deleteItem(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}