# MCP Server Implementation

This is a Swift implementation of an MCP (Model Context Protocol) server that provides system information tools.

## Overview

The Model Context Protocol (MCP) is an open protocol that standardizes how applications provide context to Large Language Models (LLMs). This Swift implementation provides a server that can expose system information through standardized MCP tools.

## Features

- **MCP Server**: Implements the MCP protocol with stdio transport
- **System Information Tools**: Provides device and system information
- **Swift Package**: Clean Swift Package Manager implementation
- **Cross-platform**: Works on macOS and can be extended for iOS

## Requirements

- macOS 13.0+ (due to MCP SDK requirements)
- Swift 5.9+
- Xcode 14.0+

## Installation

### Swift Package Manager

```swift
// Add to Package.swift
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
]
```

## Building

```bash
swift build
```

## Usage

### Running the Server

```bash
.build/debug/MCPServer
```

The server communicates via JSON-RPC over stdio. Example initialization:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "roots": {
        "listChanged": false
      }
    },
    "clientInfo": {
      "name": "test-client",
      "version": "1.0.0"
    }
  }
}
```

### Available Tools

The server provides the following tools:

1. **get_device_info**: Get current device information
   - Returns: Host name, process name, process ID

2. **get_system_info**: Get system information
   - Returns: OS version, active processors, physical memory

### Example Tool Call

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_device_info",
    "arguments": {}
  }
}
```

## Project Structure

```
MCPiPhone-iOS/
├── Package.swift              # Swift Package configuration
├── Sources/
│   └── MCPServer/
│       └── main.swift         # MCP server implementation
├── README.md                  # This file
└── test_mcp.sh               # Test script
```

## Development

### Building

```bash
swift build
```

### Testing

```bash
# Run the test script
./test_mcp.sh

# Manual testing
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}' | .build/debug/MCPServer
```

## Implementation Details

- Uses the official MCP Swift SDK (v0.9.0)
- Implements proper MCP protocol compliance
- Provides structured logging to stderr
- Handles JSON-RPC communication over stdio
- Follows MCP best practices for tool naming and schema

## License

This project is provided under the MIT License.