import SwiftUI
import MCP

struct MCPToolsViewEnhanced: View {
    @EnvironmentObject var mcpManager: MCPClientManager
    
    // Connection mode
    @State private var connectionMode: ConnectionMode = .localDemo
    
    // Local demo settings
    @State private var serverPath = "demo"
    
    // Remote server settings
    @State private var remoteURL = ""
    @State private var authToken = ""
    @State private var showAuthToken = false
    
    // Common state
    @State private var selectedTool: Tool?
    @State private var toolResponse = ""
    @State private var isConnecting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingLLMSettings = false
    @State private var hasAutoConnected = false
    
    // Settings persistence
    @AppStorage("lastRemoteURL") private var lastRemoteURL = ""
    @AppStorage("lastAuthToken") private var lastAuthToken = ""
    @AppStorage("preferredConnectionMode") private var preferredConnectionMode = ConnectionMode.localDemo.rawValue
    
    enum ConnectionMode: String, CaseIterable {
        case localDemo = "Local Demo"
        case remoteServer = "Remote Server"
        
        var icon: String {
            switch self {
            case .localDemo: return "iphone"
            case .remoteServer: return "network"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with LLM Settings
                headerSection
                
                // Connection Mode Picker
                connectionModePicker
                
                // Connection Section
                connectionSection
                
                Divider()
                
                // Server Info Section
                if mcpManager.isConnected {
                    serverInfoSection
                    
                    Divider()
                    
                    // Tools Section
                    toolsSection
                    
                    Divider()
                    
                    // Response Section
                    responseSection
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .alert("MCP Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingLLMSettings) {
                LLMSettingsView()
            }
            .onAppear {
                loadSettings()
                autoConnectIfNeeded()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Text("MCP Tools")
                .font(.largeTitle)
                .bold()
            Spacer()
            Button(action: { showingLLMSettings = true }) {
                Image(systemName: "gear")
                    .font(.title2)
            }
        }
    }
    
    private var connectionModePicker: some View {
        Picker("Connection Mode", selection: $connectionMode) {
            ForEach(ConnectionMode.allCases, id: \.self) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .disabled(mcpManager.isConnected)
        .onChange(of: connectionMode) { newMode in
            preferredConnectionMode = newMode.rawValue
        }
    }
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP Server Connection")
                .font(.headline)
            
            switch connectionMode {
            case .localDemo:
                localDemoConnectionView
            case .remoteServer:
                remoteServerConnectionView
            }
            
            // Connection button
            HStack {
                Spacer()
                
                if mcpManager.isConnected {
                    // Connection status with server type
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(mcpManager.connectionStatus)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                
                Button(action: toggleConnection) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(mcpManager.isConnected ? "Disconnect" : "Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting || (!canConnect && !mcpManager.isConnected))
            }
            
            if let error = mcpManager.connectionError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var localDemoConnectionView: some View {
        HStack {
            TextField("Server executable path", text: $serverPath)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(mcpManager.isConnected)
        }
    }
    
    private var remoteServerConnectionView: some View {
        VStack(spacing: 10) {
            // URL input
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("https://mcp-server.example.com", text: $remoteURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(mcpManager.isConnected)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }
            
            // Auth token input
            HStack {
                Image(systemName: "key")
                    .foregroundColor(.secondary)
                
                if showAuthToken {
                    TextField("Authentication Token (optional)", text: $authToken)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(mcpManager.isConnected)
                        .autocapitalization(.none)
                } else {
                    SecureField("Authentication Token (optional)", text: $authToken)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(mcpManager.isConnected)
                }
                
                Button(action: { showAuthToken.toggle() }) {
                    Image(systemName: showAuthToken ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .disabled(mcpManager.isConnected)
            }
        }
    }
    
    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server Information")
                .font(.headline)
            
            if let serverInfo = mcpManager.serverInfo {
                Label("Name: \(serverInfo.name)", systemImage: "server.rack")
                Label("Version: \(serverInfo.version)", systemImage: "info.circle")
                
                if connectionMode == .remoteServer {
                    Label("Type: Remote HTTP Server", systemImage: "network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available Tools (\(mcpManager.availableTools.count))")
                .font(.headline)
            
            if mcpManager.availableTools.isEmpty {
                Text("No tools available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(mcpManager.availableTools, id: \.name) { tool in
                            ToolRow(tool: tool, isSelected: selectedTool?.name == tool.name) {
                                callTool(tool)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tool Response")
                    .font(.headline)
                
                Spacer()
                
                if !toolResponse.isEmpty && toolResponse != "No response yet" {
                    HStack(spacing: 10) {
                        Button(action: copyResponse) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: sendToChat) {
                            Label("Ask AI", systemImage: "message")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            ScrollView {
                Text(toolResponse.isEmpty ? "No response yet" : toolResponse)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Computed Properties
    
    private var canConnect: Bool {
        switch connectionMode {
        case .localDemo:
            return !serverPath.isEmpty
        case .remoteServer:
            return !remoteURL.isEmpty && isValidURL(remoteURL)
        }
    }
    
    // MARK: - Methods
    
    private func loadSettings() {
        // Load saved remote server settings
        if !lastRemoteURL.isEmpty {
            remoteURL = lastRemoteURL
        }
        if !lastAuthToken.isEmpty {
            authToken = lastAuthToken
        }
        
        // Load preferred connection mode
        if let mode = ConnectionMode(rawValue: preferredConnectionMode) {
            connectionMode = mode
        }
    }
    
    private func saveSettings() {
        // Save remote server settings
        if connectionMode == .remoteServer {
            lastRemoteURL = remoteURL
            lastAuthToken = authToken
        }
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    private func toggleConnection() {
        if mcpManager.isConnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    private func connect() {
        isConnecting = true
        
        Task {
            do {
                switch connectionMode {
                case .localDemo:
                    try await mcpManager.connectToServer(executable: serverPath)
                case .remoteServer:
                    guard let url = URL(string: remoteURL) else {
                        throw MCPError.invalidParams("Invalid URL")
                    }
                    try await mcpManager.connectToRemoteServer(
                        url: url,
                        authToken: authToken.isEmpty ? nil : authToken
                    )
                    saveSettings()
                }
                
                await MainActor.run {
                    toolResponse = "Connected successfully! Available tools: \(mcpManager.availableTools.count)"
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    toolResponse = "Connection failed: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isConnecting = false
            }
        }
    }
    
    private func disconnect() {
        Task {
            await mcpManager.disconnect()
            await MainActor.run {
                toolResponse = "Disconnected from server"
                selectedTool = nil
            }
        }
    }
    
    private func callTool(_ tool: Tool) {
        selectedTool = tool
        
        Task {
            do {
                let result = try await mcpManager.callTool(tool.name)
                
                await MainActor.run {
                    if result.isEmpty {
                        toolResponse = "Tool executed successfully with no output"
                    } else {
                        toolResponse = result.map { content in
                            switch content {
                            case .text(let text):
                                return text.text
                            case .image(let image):
                                return "[Image: \(image.mimeType ?? "unknown")]"
                            case .resource(let resource):
                                return "[Resource: \(resource.uri)]"
                            default:
                                return "[Unknown content type]"
                            }
                        }.joined(separator: "\n\n")
                    }
                }
            } catch {
                await MainActor.run {
                    toolResponse = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func copyResponse() {
        UIPasteboard.general.string = toolResponse
    }
    
    private func sendToChat() {
        guard let tool = selectedTool else { return }
        
        NotificationCenter.default.post(
            name: Notification.Name("SwitchToChatWithToolOutput"),
            object: nil,
            userInfo: [
                "toolName": tool.name,
                "output": toolResponse
            ]
        )
    }
    
    private func autoConnectIfNeeded() {
        guard DevelopmentConfig.autoConnectMCP,
              !hasAutoConnected,
              !mcpManager.isConnected else { return }
        
        hasAutoConnected = true
        
        Task {
            isConnecting = true
            
            do {
                // Add a small delay to ensure UI is ready
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Try to connect based on saved mode
                switch connectionMode {
                case .localDemo:
                    try await mcpManager.connectToServer(executable: serverPath)
                case .remoteServer:
                    if !remoteURL.isEmpty, let url = URL(string: remoteURL) {
                        try await mcpManager.connectToRemoteServer(
                            url: url,
                            authToken: authToken.isEmpty ? nil : authToken
                        )
                    } else {
                        // Fall back to local demo if no remote URL saved
                        connectionMode = .localDemo
                        try await mcpManager.connectToServer(executable: serverPath)
                    }
                }
                
                // Show success message
                await MainActor.run {
                    toolResponse = "MCP Server connected successfully! Available tools: \(mcpManager.availableTools.count)"
                }
            } catch {
                // Log the error but don't show alert for auto-connection
                print("[MCP Auto-connect] Failed: \(error.localizedDescription)")
                
                // Show a subtle error message in the response area
                await MainActor.run {
                    toolResponse = "MCP Server auto-connection failed. You can manually connect using the Connect button."
                }
            }
            
            await MainActor.run {
                isConnecting = false
            }
        }
    }
}