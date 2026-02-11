> ## ⚠️ This project has evolved into [Elio Chat](https://github.com/yukihamada/elio)
> 
> Elio Chat is a full-featured local AI agent for iOS with MCP integration, 30+ models, vision AI, and voice input.
> 
> **Download**: [App Store](https://apps.apple.com/jp/app/elio-chat/id6757635481) | **Website**: [elio.love](https://elio.love)
>
> ---

# MCP iOS SDK Implementation with LLM Integration

This project demonstrates how to integrate the Swift MCP (Model Context Protocol) SDK into an iOS application with LLM support through Cloudflare Workers and local models, including both client and server implementations.

## Overview

The Model Context Protocol (MCP) is an open protocol that standardizes how applications provide context to Large Language Models (LLMs). This Swift implementation enables iOS apps to:

- Connect to MCP servers using stdio transport
- Host MCP servers that expose device capabilities
- Exchange data and execute tools through a standardized protocol
- Use Groq API through Cloudflare Workers with rate limiting
- Fall back to local LLM models when offline or rate-limited
- Manage API keys with tiered access (anonymous/free/pro)

## Requirements

- iOS 15.0+ / macOS 12.0+
- Xcode 14.0+
- Swift 5.9+

## Important: Sandboxing Configuration

⚠️ **Critical**: To use stdio transport for MCP servers in iOS/macOS apps, you **MUST disable sandboxing**. This is because the app needs to spawn and manage external processes, which is restricted in a sandboxed environment.

### Disabling Sandboxing

1. Open your project in Xcode
2. Select your app target
3. Go to "Signing & Capabilities" tab
4. Remove the "App Sandbox" capability, or
5. Edit the `.entitlements` file and set:
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <false/>
   ```

**Security Note**: Disabling sandboxing reduces your app's security. Only do this for:
- Development builds
- Internal tools
- Trusted environments

For production apps, consider alternative transport methods or carefully evaluate the security implications.

## Installation

### Swift Package Manager

Add the MCP SDK to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/modelcontextprotocol/swift-sdk.git`
3. Version: "Up to Next Major" from "0.9.0"

## LLM Integration Features

### Cloudflare Worker Gateway
- **Authentication**: Anonymous and email-based registration
- **Rate Limiting**: 10 req/hr (anonymous), 1000 req/hr (registered)
- **API Key Management**: Secure key generation and storage
- **Groq API Proxy**: Hides actual API keys from clients

### Local LLM Support
- **Models**: Jan-Nano variants (2.3GB each)
- **Auto-fallback**: Switches to local when rate-limited
- **Background Downloads**: Models download while using the app
- **GPU Acceleration**: Uses Metal for fast inference

### Setup Cloudflare Worker

1. Install dependencies:
```bash
cd cloudflare-worker
npm install
```

2. Configure Wrangler:
```bash
# Set your Groq API key
wrangler secret put GROQ_API_KEY

# Deploy to Cloudflare
wrangler deploy
```

3. Update iOS app with your worker URL:
```swift
// In AuthManager.swift
private let baseURL = "https://your-worker.workers.dev"
```

## Project Structure

```
mcp-iphone/
├── MCPiPhone/
│   ├── MCPiPhoneApp.swift          # Main app entry point
│   ├── Info.plist                  # App configuration
│   ├── MCPiPhone.entitlements      # Entitlements (sandboxing disabled)
│   ├── LLM/                        # LLM integration
│   │   ├── LLMProvider.swift       # Provider protocol
│   │   ├── LLMConfiguration.swift  # Settings management
│   │   ├── Providers/
│   │   │   ├── CloudflareProvider.swift
│   │   │   └── LocalLLMProvider.swift
│   │   └── Models/
│   │       ├── Model.swift
│   │       └── ModelManager.swift
│   ├── Auth/
│   │   └── AuthManager.swift       # API key management
│   ├── MCP/
│   │   ├── MCPClientManager.swift  # MCP client wrapper
│   │   ├── SampleMCPServer.swift   # Sample server implementation
│   │   └── MCPServerRunner.swift   # Server process runner
│   └── Views/
│       └── ContentView.swift       # Demo UI
├── Sources/
│   └── MCPServer/
│       └── main.swift              # CLI server executable
└── Package.swift                   # Package dependencies
```

## Usage

### 1. MCP Client

The `MCPClientManager` provides a high-level interface for connecting to MCP servers:

```swift
import MCPiPhone

// Initialize the manager
let mcpManager = MCPClientManager()

// Connect to a server
try await mcpManager.connectToServer(
    executable: "/path/to/mcp-server",
    args: ["--arg1", "value1"],
    env: ["API_KEY": "your-key"]
)

// List available tools
let tools = mcpManager.availableTools

// Call a tool
let response = try await mcpManager.callTool(
    "get_device_info",
    arguments: [:]
)
```

### 2. MCP Server

The sample server exposes iOS device capabilities through MCP tools:

```swift
// Available tools:
- get_device_info      // Device model, name, identifier
- get_battery_status   // Battery level and charging state
- get_system_version   // iOS version and system info
- get_screen_info      // Screen dimensions and scale
- get_memory_info      // Memory and processor information

// Available resources:
- device://capabilities  // Device feature availability
- app://info            // App bundle information
```

### 3. Running the Demo

1. Open the project in Xcode
2. Ensure sandboxing is disabled (see above)
3. Build and run the iOS app
4. To test with the sample server:
   - Build the server executable: `swift build -c release`
   - Enter the path to the built executable in the app
   - Click "Connect"

## Implementation Details

### Client Features

- Automatic reconnection handling
- Async/await support
- Observable state management for SwiftUI
- Comprehensive error handling and logging
- Tool discovery and invocation

### Server Features

- Device information tools
- Resource endpoints for capabilities
- Structured logging to stderr (not stdout)
- Proper MCP protocol compliance

### Best Practices

1. **Tool Naming**: Use snake_case for tool names (e.g., `get_device_info`)
2. **Input Schema**: Always provide input schema for tools, even if empty
3. **Logging**: Use stderr for logging, never stdout (reserved for MCP protocol)
4. **Error Handling**: Implement proper error types and descriptive messages

## Examples

### Connecting to a Server

```swift
// In your SwiftUI view
@StateObject private var mcpManager = MCPClientManager()

// Connect to server
Task {
    try await mcpManager.connectToServer(
        executable: "/usr/local/bin/my-mcp-server"
    )
}

// Use in UI
if mcpManager.isConnected {
    ForEach(mcpManager.availableTools, id: \.name) { tool in
        Button(tool.name) {
            Task {
                let result = try await mcpManager.callTool(tool.name)
                print(result)
            }
        }
    }
}
```

### Creating a Custom Tool

```swift
// In your server implementation
let customTool = Tool(
    name: "my_custom_tool",
    description: "Does something custom",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "param1": .object(["type": .string("string")])
        ])
    ])
)

// Handle the tool call
await server.withMethodHandler(CallTool.self) { params in
    if params.name == "my_custom_tool" {
        let param1 = params.arguments["param1"] as? String ?? ""
        return CallTool.Result(content: [
            .text("Processed: \(param1)")
        ])
    }
    throw MCPError.invalidParams("Unknown tool")
}
```

## Troubleshooting

### Common Issues

1. **"Operation not permitted" error**
   - Ensure sandboxing is disabled
   - Check file permissions on the server executable

2. **Server not responding**
   - Verify the server path is correct
   - Check server logs on stderr
   - Ensure the server implements stdio transport

3. **Tools not appearing**
   - Verify server capabilities include tools
   - Check tool registration in server
   - Ensure input schema is provided

### Debug Tips

- Enable verbose logging by setting log level
- Monitor stderr for server logs
- Use Xcode's console for client-side debugging
- Test server independently using command line

## Security Considerations

1. **Sandboxing**: Disabling sandboxing reduces security
2. **Process Execution**: Be careful about which executables you allow
3. **Data Privacy**: Consider what device information you expose
4. **Network Security**: Use secure transport for production

## Resources

- [Official MCP Documentation](https://modelcontextprotocol.io)
- [Swift SDK Repository](https://github.com/modelcontextprotocol/swift-sdk)
- [MCP Specification](https://spec.modelcontextprotocol.io)

## License

This example project is provided under the MIT License. The MCP Swift SDK is also MIT licensed.