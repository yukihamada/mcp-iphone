# MCP iPhone Cloudflare Worker Gateway

This Cloudflare Worker serves as an API gateway for the MCP iPhone app, providing authentication, rate limiting, and secure proxy access to Groq's LLM API.

## Features

- **Authentication System**
  - Anonymous account creation
  - Email-based registration
  - JWT token generation
  - API key management

- **Rate Limiting**
  - Anonymous: 10 requests/hour
  - Free tier: 1,000 requests/hour
  - Pro tier: 10,000 requests/hour

- **Groq API Proxy**
  - Secure API key storage
  - Request/response forwarding
  - SSE streaming support

## Setup

### Prerequisites

- Node.js 18+
- Cloudflare account
- Wrangler CLI (`npm install -g wrangler`)
- Groq API key

### Installation

1. Install dependencies:
```bash
npm install
```

2. Configure Wrangler:
```bash
# Login to Cloudflare
wrangler login

# Create KV namespaces
wrangler kv:namespace create USERS
wrangler kv:namespace create RATE_LIMITS

# Create D1 database
wrangler d1 create mcp-iphone
```

3. Update `wrangler.toml` with your namespace IDs:
```toml
[[kv_namespaces]]
binding = "USERS"
id = "YOUR_USERS_KV_ID"

[[kv_namespaces]]
binding = "RATE_LIMITS"
id = "YOUR_RATE_LIMITS_KV_ID"

[[d1_databases]]
binding = "DB"
database_name = "mcp-iphone"
database_id = "YOUR_D1_DATABASE_ID"
```

4. Set your Groq API key:
```bash
wrangler secret put GROQ_API_KEY
```

### Development

Run locally with:
```bash
npm run dev
```

### Deployment

Deploy to Cloudflare:
```bash
npm run deploy
```

## API Endpoints

### Health Check
```
GET /health
```

### Create Anonymous Account
```
POST /api/auth/anonymous
```

Response:
```json
{
  "apiKey": "mcp_anon_xxxxx",
  "token": "jwt.token.here",
  "tier": "anonymous",
  "rateLimit": {
    "requests": 10,
    "period": 3600
  }
}
```

### Register with Email
```
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com"
}
```

Response:
```json
{
  "apiKey": "mcp_xxxxx",
  "token": "jwt.token.here",
  "tier": "free",
  "rateLimit": {
    "requests": 1000,
    "period": 3600
  }
}
```

### Groq API Proxy
```
POST /api/groq/chat/completions
X-API-Key: your-api-key
Content-Type: application/json

{
  "model": "llama-3.3-70b-versatile",
  "messages": [
    {"role": "user", "content": "Hello"}
  ]
}
```

## Rate Limit Headers

All API responses include rate limit information:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 2024-01-01T00:00:00Z
```

## Security

- API keys are generated using nanoid (cryptographically secure)
- Groq API key is stored as a Worker secret
- CORS is configured for cross-origin requests
- JWT tokens expire after 30 days

## Error Handling

The API returns standard HTTP status codes:
- `401` - Invalid or missing API key
- `429` - Rate limit exceeded
- `500` - Internal server error

Error responses include a JSON body:
```json
{
  "error": "Rate limit exceeded",
  "resetAt": "2024-01-01T00:00:00Z",
  "suggestion": "Register with email for higher limits"
}
```

## Monitoring

Monitor your Worker at:
https://dash.cloudflare.com/

Key metrics to track:
- Request count by tier
- Rate limit violations
- API response times
- Error rates

## License

MIT