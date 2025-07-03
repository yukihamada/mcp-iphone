# Remote MCP Server Support

This document describes the implementation for connecting to remote MCP servers over HTTP/HTTPS from the iOS app.

## Overview

The MCP iPhone app now supports connecting to remote MCP servers in addition to local stdio-based servers. This enables:

- Connecting to cloud-hosted MCP servers
- No need to disable iOS app sandboxing
- Authentication via bearer tokens
- Automatic retry and error handling
- Support for both HTTP and WebSocket transports

## Implementation Status

### ✅ Completed

1. **HTTPTransport Class** (`MCPiPhone-App/MCPiPhone/MCP/HTTPTransport.swift`)
   - Implements MCP Transport protocol for HTTP/HTTPS
   - WebSocket support for bidirectional communication
   - Polling fallback for servers without WebSocket
   - Authentication header support

2. **RemoteMCPClient** (`MCPiPhone-App/MCPiPhone/MCP/RemoteMCPClient.swift`)
   - Standalone client for remote MCP servers
   - Retry logic with exponential backoff
   - Connection state management
   - Tool discovery and invocation

3. **Enhanced MCPClientManager** 
   - Support for both local and remote connections
   - Connection mode tracking
   - Backward compatibility maintained

4. **Updated UI** (`MCPiPhone-App/MCPiPhone/Views/MCPToolsViewEnhanced.swift`)
   - Toggle between local demo and remote server
   - URL and authentication token input
   - Connection status display
   - Tool response copying

### ⚠️ Limitations

1. **MCP SDK Integration**: The HTTPTransport is not yet integrated into the official MCP Swift SDK. The current implementation works around this by using a separate RemoteMCPClient.

2. **Protocol Mapping**: Remote servers need to implement HTTP endpoints that map to MCP protocol operations:
   - `POST /initialize` - Initialize connection
   - `GET /tools/list` - List available tools  
   - `POST /tools/call` - Call a tool
   - `GET /poll` - Poll for messages (optional)
   - `WS /ws` - WebSocket connection (optional)

## Usage

### For App Users

1. Open the MCP Tools view in the app
2. Select "Remote Server" from the connection type picker
3. Enter the server URL (e.g., `https://your-mcp-server.com`)
4. Optionally enter an authentication token
5. Tap "Connect"

### For Server Implementers

Your HTTP MCP server should implement these endpoints:

#### 1. Initialize Connection
```http
POST /initialize
Content-Type: application/json
Authorization: Bearer <token>

{
  "protocolVersion": "1.0",
  "capabilities": {
    "tools": {}
  },
  "clientInfo": {
    "name": "MCPiPhone",
    "version": "1.0.0"
  }
}
```

Response:
```json
{
  "protocolVersion": "1.0",
  "capabilities": {
    "tools": {}
  },
  "serverInfo": {
    "name": "Your Server Name",
    "version": "1.0.0"
  }
}
```

#### 2. List Tools
```http
GET /tools/list
Authorization: Bearer <token>
```

Response:
```json
{
  "tools": [
    {
      "name": "example_tool",
      "description": "An example tool",
      "inputSchema": {
        "type": "object",
        "properties": {},
        "required": []
      }
    }
  ]
}
```

#### 3. Call Tool
```http
POST /tools/call
Content-Type: application/json
Authorization: Bearer <token>

{
  "name": "example_tool",
  "arguments": {
    "param1": "value1"
  }
}
```

Response:
```json
{
  "content": [
    {
      "type": "text",
      "text": "Tool response text"
    }
  ]
}
```

## Configuration

### Client Configuration

```swift
let config = RemoteMCPServerConfig(
    url: URL(string: "https://your-server.com")!,
    authToken: "your-auth-token",
    timeout: 30,           // Request timeout in seconds
    maxRetries: 3,         // Number of retry attempts
    retryDelay: 2.0        // Delay between retries in seconds
)
```

### Error Handling

The client includes automatic retry logic for:
- Network timeouts
- Connection failures
- 5xx server errors

It will NOT retry for:
- Authentication errors (401, 403)
- Client errors (400, 404)
- Invalid requests

## Security Considerations

1. **HTTPS Required**: Always use HTTPS for production servers
2. **Authentication**: Use bearer tokens or API keys
3. **CORS**: Configure appropriate CORS headers for web-based clients
4. **Rate Limiting**: Implement rate limiting on your server
5. **Input Validation**: Validate all tool inputs on the server side

## Future Enhancements

1. **SDK Integration**: Integrate HTTPTransport into the official MCP Swift SDK
2. **Certificate Pinning**: Add certificate pinning for enhanced security
3. **Compression**: Support gzip/deflate for large responses
4. **Caching**: Implement response caching for read-only operations
5. **Metrics**: Add performance monitoring and analytics

## Example Server Implementation

Here's a minimal Express.js server that implements the required endpoints:

```javascript
const express = require('express');
const app = express();

app.use(express.json());

// Middleware for authentication
app.use((req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

// Initialize endpoint
app.post('/initialize', (req, res) => {
  res.json({
    protocolVersion: '1.0',
    capabilities: { tools: {} },
    serverInfo: {
      name: 'Example MCP Server',
      version: '1.0.0'
    }
  });
});

// List tools
app.get('/tools/list', (req, res) => {
  res.json({
    tools: [
      {
        name: 'hello_world',
        description: 'Says hello',
        inputSchema: {
          type: 'object',
          properties: {
            name: { type: 'string' }
          }
        }
      }
    ]
  });
});

// Call tool
app.post('/tools/call', (req, res) => {
  const { name, arguments } = req.body;
  
  if (name === 'hello_world') {
    res.json({
      content: [{
        type: 'text',
        text: `Hello, ${arguments.name || 'World'}!`
      }]
    });
  } else {
    res.status(404).json({ error: 'Tool not found' });
  }
});

app.listen(3000, () => {
  console.log('MCP server running on http://localhost:3000');
});
```

## Testing

To test remote server connections:

1. Deploy a test server (can use the example above)
2. Open the iOS app
3. Switch to "Remote Server" mode
4. Enter your server URL
5. Add authentication token if required
6. Connect and test tool calls

For local testing, you can use ngrok to expose a local server:
```bash
ngrok http 3000
```

Then use the ngrok URL in the iOS app.