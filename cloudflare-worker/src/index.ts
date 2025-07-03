import { Env } from './types';
import { SimpleAuthService } from './auth-simple';
import { GroqProxyService } from './groqProxy';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const authService = new SimpleAuthService(env);
    const groqProxy = new GroqProxyService(env);

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-Key',
      'Access-Control-Max-Age': '86400',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Health check
      if (url.pathname === '/health') {
        return new Response(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Create anonymous API key
      if (url.pathname === '/api/auth/anonymous' && request.method === 'POST') {
        const user = authService.createAnonymousUser();
        
        return new Response(JSON.stringify({
          apiKey: user.apiKey,
          token: 'demo-token',
          tier: user.tier,
          rateLimit: {
            requests: 10,
            period: 3600
          }
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Create verified user (email verification)
      if (url.pathname === '/api/auth/register' && request.method === 'POST') {
        const { email } = await request.json() as { email: string };
        
        if (!email || !email.includes('@')) {
          return new Response(JSON.stringify({ error: 'Invalid email' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const user = authService.createVerifiedUser(email);
        
        return new Response(JSON.stringify({
          apiKey: user.apiKey,
          token: 'demo-token',
          tier: user.tier,
          rateLimit: {
            requests: 1000,
            period: 3600
          }
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Protected routes - simple validation
      const apiKey = request.headers.get('X-API-Key') || request.headers.get('Authorization')?.replace('Bearer ', '');
      
      if (!apiKey && url.pathname.startsWith('/api/groq')) {
        return new Response(JSON.stringify({ error: 'API key required' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Simple rate limiting (in production, use KV)
      const rateLimitInfo = await authService.validateApiKey(apiKey || '');
      
      // Proxy Groq API requests
      if (url.pathname.startsWith('/api/groq')) {
        if (!env.GROQ_API_KEY) {
          return new Response(JSON.stringify({ error: 'Groq API key not configured' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const response = await groqProxy.proxyRequest(request);
        
        // Add CORS headers
        const responseHeaders = new Headers(response.headers);
        Object.entries(corsHeaders).forEach(([key, value]) => {
          responseHeaders.set(key, value);
        });
        
        if (rateLimitInfo) {
          responseHeaders.set('X-RateLimit-Limit', rateLimitInfo.rateLimit.requests.toString());
          responseHeaders.set('X-RateLimit-Remaining', (rateLimitInfo.rateLimit.requests - 1).toString());
          responseHeaders.set('X-RateLimit-Reset', new Date(Date.now() + rateLimitInfo.rateLimit.period * 1000).toISOString());
        }
        
        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: responseHeaders
        });
      }

      // Web search endpoint
      if (url.pathname === '/api/search/web' && request.method === 'POST') {
        const authHeader = request.headers.get('Authorization');
        if (!authHeader?.startsWith('Bearer ')) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        const searchApiKey = authHeader.substring(7);
        const user = authService.validateApiKey(searchApiKey);
        
        if (!user) {
          return new Response(JSON.stringify({ error: 'Invalid API key' }), {
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }

        try {
          const body = await request.json();
          const query = body.query;
          
          if (!query || typeof query !== 'string') {
            return new Response(JSON.stringify({ error: 'Missing query parameter' }), {
              status: 400,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
          }

          // Use DuckDuckGo Instant Answer API (free, no auth required)
          const searchUrl = `https://api.duckduckgo.com/?q=${encodeURIComponent(query)}&format=json&no_html=1&skip_disambig=1`;
          const searchResponse = await fetch(searchUrl);
          const searchData = await searchResponse.json();

          let results = [];
          
          // Add instant answer if available
          if (searchData.Abstract && searchData.AbstractText) {
            results.push({
              title: searchData.Heading || query,
              snippet: searchData.AbstractText,
              url: searchData.AbstractURL || '',
              source: searchData.AbstractSource || 'DuckDuckGo'
            });
          }

          // Add related topics
          if (searchData.RelatedTopics && Array.isArray(searchData.RelatedTopics)) {
            for (const topic of searchData.RelatedTopics.slice(0, 5)) {
              if (topic.Text && topic.FirstURL) {
                results.push({
                  title: topic.Text.split(' - ')[0] || topic.Text,
                  snippet: topic.Text,
                  url: topic.FirstURL,
                  source: 'Related'
                });
              }
            }
          }

          // If no results, provide a fallback
          if (results.length === 0) {
            results.push({
              title: `Search results for "${query}"`,
              snippet: 'No specific results found. Try refining your search query.',
              url: `https://duckduckgo.com/?q=${encodeURIComponent(query)}`,
              source: 'DuckDuckGo'
            });
          }

          return new Response(JSON.stringify({
            query: query,
            results: results,
            timestamp: new Date().toISOString()
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        } catch (error) {
          return new Response(JSON.stringify({ 
            error: 'Search failed', 
            details: error.message 
          }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }
      }

      // 404 for other routes
      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({
        error: 'Internal server error',
        details: error instanceof Error ? error.message : 'Unknown error'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  },
};