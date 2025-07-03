#!/bin/bash

SERVER_PATH=".build/debug/MCPServer"

# Function to test MCP server
test_mcp() {
    echo "Testing MCP Server..."
    
    # Test initialization
    echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {"roots": {"listChanged": false}}, "clientInfo": {"name": "test-client", "version": "1.0.0"}}}' | $SERVER_PATH &
    SERVER_PID=$!
    
    sleep 2
    
    # Kill server
    kill $SERVER_PID 2>/dev/null
    
    echo "MCP Server test completed"
}

test_mcp