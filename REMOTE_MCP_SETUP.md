# Remote MCP Server Setup Guide

This guide explains how to connect the MCPiPhone app to remote MCP servers.

## Overview

MCPiPhone now supports connecting to both local demo servers and remote MCP servers over HTTP/HTTPS. This enables you to:

- Connect to MCP servers running on other devices or in the cloud
- Use authentication tokens for secure connections
- Persist connection settings between app launches

## Quick Start

1. Open the MCPiPhone app
2. Go to the "MCP Tools" tab
3. Select "Remote Server" from the connection mode picker
4. Enter your server URL (e.g., `https://my-mcp-server.com`)
5. (Optional) Enter an authentication token
6. Tap "Connect"

## Server Requirements

Your remote MCP server must:

1. Support HTTP/HTTPS protocol
2. Implement the MCP protocol endpoints:
   - `POST /initialize` - Initialize connection
   - `GET /tools/list` - List available tools
   - `POST /tools/call` - Execute tool calls
3. Handle CORS headers for iOS app connections
4. (Optional) Support authentication via Bearer tokens

## Example Server Implementation

Here's a minimal example using Node.js and Express:

```javascript
const express = require('express');
const app = express();

app.use(express.json());

// CORS middleware
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  next();
});

// Initialize endpoint
app.post('/initialize', (req, res) => {
  res.json({
    protocolVersion: '1.0',
    capabilities: { tools: {} },
    serverInfo: {
      name: 'My MCP Server',
      version: '1.0.0'
    }
  });
});

// List tools endpoint
app.get('/tools/list', (req, res) => {
  res.json({
    tools: [
      {
        name: 'hello_world',
        description: 'Says hello',
        inputSchema: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'Name to greet' }
          },
          required: ['name']
        }
      }
    ]
  });
});

// Call tool endpoint
app.post('/tools/call', (req, res) => {
  const { name, arguments: args } = req.body;
  
  if (name === 'hello_world') {
    res.json({
      content: [{
        type: 'text',
        text: `Hello, ${args.name || 'World'}!`
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

## Authentication

To secure your MCP server:

1. Generate an authentication token
2. Configure your server to validate Bearer tokens
3. Enter the token in the MCPiPhone app

Example server authentication:

```javascript
app.use((req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7);
    
    if (token === process.env.MCP_AUTH_TOKEN) {
      next();
    } else {
      res.status(401).json({ error: 'Invalid token' });
    }
  } else {
    res.status(401).json({ error: 'Authentication required' });
  }
});
```

## Connection Settings

The app automatically saves:
- Last used remote server URL
- Authentication token (stored securely)
- Preferred connection mode (Local Demo vs Remote Server)

## Troubleshooting

### Connection Failed
- Verify the server URL is correct and accessible
- Check that the server implements required endpoints
- Ensure CORS headers are properly configured
- Verify authentication token if required

### Tool Calls Failing
- Check server logs for errors
- Verify tool names match exactly
- Ensure request/response format follows MCP protocol
- Check network connectivity

### SSL/TLS Issues
- Use HTTPS for production servers
- Ensure SSL certificates are valid
- For development, you may need to allow insecure connections (not recommended for production)

## Advanced Features

### WebSocket Support
The app supports WebSocket connections for real-time bidirectional communication. Your server can implement WebSocket endpoints at `/ws` for persistent connections.

### Retry Logic
The app automatically retries failed connections and tool calls with exponential backoff. Configure retry behavior in server settings.

### Connection Pooling
For high-performance scenarios, the app maintains connection pools to reduce latency.

## Security Best Practices

1. Always use HTTPS in production
2. Implement proper authentication
3. Validate all inputs on the server
4. Use rate limiting to prevent abuse
5. Log all tool calls for auditing
6. Implement proper error handling without exposing sensitive information

## Next Steps

- Explore the [MCP Protocol Specification](https://github.com/anthropics/mcp)
- Check out example server implementations
- Join the MCP community for support and updates