import SwiftUI
import MCP

struct ContentView: View {
    @StateObject private var mcpManager = MCPClientManager()
    @State private var serverPath = ""
    @State private var selectedTool: Tool?
    @State private var toolResponse = ""
    @State private var isConnecting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingLLMSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with LLM Settings
                HStack {
                    Text("MCP iOS Demo")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    Button(action: { showingLLMSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                
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
        }
        .onAppear {
            // Create anonymous account on first launch if needed
            if !AuthManager.shared.isAuthenticated {
                Task {
                    try? await AuthManager.shared.createAnonymousAccount()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP Server Connection")
                .font(.headline)
            
            HStack {
                TextField("Server executable path", text: $serverPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(mcpManager.isConnected)
                
                Button(action: toggleConnection) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(mcpManager.isConnected ? "Disconnect" : "Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting || (serverPath.isEmpty && !mcpManager.isConnected))
            }
            
            if let error = mcpManager.connectionError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available Tools")
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
            Text("Tool Response")
                .font(.headline)
            
            ScrollView {
                Text(toolResponse.isEmpty ? "No response yet" : toolResponse)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Actions
    
    private func toggleConnection() {
        if mcpManager.isConnected {
            Task {
                await mcpManager.disconnect()
                serverPath = ""
                toolResponse = ""
                selectedTool = nil
            }
        } else {
            isConnecting = true
            Task {
                do {
                    try await mcpManager.connectToServer(executable: serverPath)
                } catch {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
                isConnecting = false
            }
        }
    }
    
    private func callTool(_ tool: Tool) {
        selectedTool = tool
        toolResponse = "Calling \(tool.name)..."
        
        Task {
            do {
                let contents = try await mcpManager.callTool(tool.name)
                
                // Convert contents to string
                let response = contents.map { content -> String in
                    switch content {
                    case .text(let text):
                        return text
                    case .image(let data, let mimeType):
                        return "[Image: \(mimeType ?? "unknown") - \(data.count) bytes]"
                    case .resource(let resource):
                        return "[Resource: \(resource.uri)]"
                    }
                }.joined(separator: "\n")
                
                await MainActor.run {
                    toolResponse = response
                }
            } catch {
                await MainActor.run {
                    toolResponse = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Tool Row View

struct ToolRow: View {
    let tool: Tool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tool.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if let description = tool.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}