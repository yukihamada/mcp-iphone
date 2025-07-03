import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MCPToolsView()
                .tabItem {
                    Label("MCP Tools", systemImage: "wrench.and.screwdriver")
                }
                .tag(0)
            
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .tag(1)
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
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}