# Example HTTP MCP Server

This is a simple example of an HTTP-based MCP server that can be used to test remote MCP connections from the iOS app.

## Features

- RESTful HTTP endpoints for MCP protocol
- No authentication required (configurable)
- CORS enabled for cross-origin requests
- Four demo tools for testing

## Quick Start

1. Install dependencies:
```bash
npm install
```

2. Start the server:
```bash
npm start
```

The server will start on port 3000 by default.

## Testing with the iOS App

1. Start this server locally
2. Open the MCP iPhone app
3. Go to MCP Tools view
4. Select "Remote Server"
5. Enter URL: `http://localhost:3000` (or use your machine's IP address)
6. Leave authentication token empty
7. Tap "Connect"

## Available Tools

### 1. get_current_time
Get the current time in various formats.

Parameters:
- `format` (optional): "iso", "unix", or "human"
- `timezone` (optional): e.g., "America/New_York"

### 2. calculate
Perform basic mathematical calculations.

Parameters:
- `expression` (required): Mathematical expression to evaluate

### 3. get_random_fact
Get a random interesting fact.

Parameters:
- `category` (optional): "science", "history", "technology", or "general"

### 4. echo
Echo back a message.

Parameters:
- `message` (required): Message to echo
- `uppercase` (optional): Convert to uppercase

## Testing with curl

Test the server endpoints:

```bash
# Health check
curl http://localhost:3000/health

# Initialize connection
curl -X POST http://localhost:3000/initialize \
  -H "Content-Type: application/json" \
  -d '{"protocolVersion":"1.0","clientInfo":{"name":"test","version":"1.0"}}'

# List tools
curl http://localhost:3000/tools/list

# Call a tool
curl -X POST http://localhost:3000/tools/call \
  -H "Content-Type: application/json" \
  -d '{"name":"get_current_time","arguments":{"format":"human"}}'
```

## Deployment Options

### Using ngrok (for local testing)
```bash
ngrok http 3000
```
Then use the ngrok URL in the iOS app.

### Using Heroku
```bash
heroku create your-mcp-server
git push heroku main
```

### Using Vercel
```bash
vercel
```

## Security Notes

- This example server has minimal security for demo purposes
- For production use:
  - Implement proper authentication
  - Use HTTPS
  - Add rate limiting
  - Validate all inputs
  - Use a proper math parser instead of eval() for the calculate tool