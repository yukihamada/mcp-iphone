import SwiftUI

struct LLMSettingsView: View {
    @ObservedObject var llmConfig = LLMConfiguration.shared
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var modelManager = ModelManager.shared
    
    @State private var showingEmailInput = false
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                // Authentication Section
                Section {
                    if authManager.isAuthenticated {
                        HStack {
                            Label("API Key", systemImage: "key.fill")
                            Spacer()
                            Text(authManager.apiKey?.prefix(8) ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("...")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Tier", systemImage: "crown.fill")
                            Spacer()
                            Text(authManager.userTier.rawValue.capitalized)
                                .foregroundColor(tierColor)
                        }
                        
                        if let rateLimit = authManager.rateLimit {
                            HStack {
                                Label("Rate Limit", systemImage: "speedometer")
                                Spacer()
                                Text("\(rateLimit.requests) requests/hour")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: { authManager.logout() }) {
                            Label("Logout", systemImage: "arrow.right.square")
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: createAnonymousAccount) {
                            HStack {
                                Label("Create Anonymous Account", systemImage: "person.crop.circle.badge.plus")
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(isLoading)
                        
                        Button(action: { showingEmailInput = true }) {
                            Label("Register with Email", systemImage: "envelope.fill")
                        }
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    } else if authManager.userTier == .anonymous {
                        Text("Anonymous accounts are limited to 10 requests/hour. Register with email for 1000 requests/hour.")
                    }
                }
                
                // Provider Selection
                Section {
                    Picker("LLM Provider", selection: $llmConfig.selectedProvider) {
                        ForEach(LLMConfiguration.LLMProviderType.allCases, id: \.self) { provider in
                            Label(provider.rawValue, systemImage: provider.icon)
                                .tag(provider)
                        }
                    }
                    
                    Toggle("Auto-fallback to Local", isOn: $llmConfig.autoFallbackToLocal)
                } header: {
                    Text("LLM Provider")
                } footer: {
                    Text("When rate limited or offline, automatically switch to local LLM. Note: Local LLM integration is still under development and will show placeholder responses.")
                }
                
                // Local Models
                Section {
                    ForEach(modelManager.models) { model in
                        ModelRow(model: model)
                    }
                } header: {
                    Text("Local Models")
                } footer: {
                    Text("Download models to use offline. Each model is approximately 2.3GB.")
                }
            }
            .navigationTitle("LLM Settings")
            .sheet(isPresented: $showingEmailInput) {
                EmailRegistrationView(email: $email) { registeredEmail in
                    Task {
                        registerWithEmail(registeredEmail)
                    }
                }
            }
        }
    }
    
    private var tierColor: Color {
        switch authManager.userTier {
        case .anonymous: return .gray
        case .free: return .blue
        case .pro: return .purple
        }
    }
    
    private func createAnonymousAccount() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.createAnonymousAccount()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func registerWithEmail(_ email: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.registerWithEmail(email)
                showingEmailInput = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct ModelRow: View {
    let model: Model
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var llmConfig = LLMConfiguration.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.name)
                    .font(.headline)
                Text(model.sizeFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let progress = modelManager.activeDownloads[model.id] {
                VStack {
                    ProgressView(value: progress.percentage, total: 100)
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    Text("\(Int(progress.percentage))%")
                        .font(.caption2)
                }
                .frame(width: 60)
            } else {
                switch model.status {
                case .notDownloaded:
                    Button(action: { modelManager.downloadModel(model.id) }) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.blue)
                    }
                case .downloading:
                    Button(action: { modelManager.cancelDownload(model.id) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                case .downloaded:
                    HStack(spacing: 12) {
                        if llmConfig.selectedLocalModel == model.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button(action: { llmConfig.selectLocalModel(model.id) }) {
                                Text("Select")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Button(action: { modelManager.deleteModel(model.id) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                case .failed:
                    Button(action: { modelManager.downloadModel(model.id) }) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmailRegistrationView: View {
    @Binding var email: String
    let onRegister: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } header: {
                    Text("Enter your email")
                } footer: {
                    Text("You'll receive an API key with higher rate limits (1000 requests/hour).")
                }
            }
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register") {
                        onRegister(email)
                    }
                    .disabled(email.isEmpty || !email.contains("@"))
                }
            }
        }
    }
}