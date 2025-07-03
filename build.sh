#!/bin/bash

# Build script for MCP iPhone project

echo "Building MCP iOS Server..."

# Navigate to project directory
cd MCPiPhone

# Build the server executable
swift build -c release --product mcp-ios-server

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "Server executable location: .build/release/mcp-ios-server"
    
    # Create a convenient symlink
    ln -sf .build/release/mcp-ios-server mcp-server
    echo "Created symlink: mcp-server -> .build/release/mcp-ios-server"
else
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "To use the server in the iOS app, enter the following path:"
echo "$(pwd)/mcp-server"