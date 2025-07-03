import { Env } from './types';
import { AuthService } from './auth';
import { RateLimitService } from './rateLimit';
import { GroqProxyService } from './groqProxy';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const authService = new AuthService(env);
    const rateLimitService = new RateLimitService(env);
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
        const user = await authService.createAnonymousUser();
        const token = await authService.generateJWT(user);
        
        return new Response(JSON.stringify({
          apiKey: user.apiKey,
          token,
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

        const user = await authService.createVerifiedUser(email);
        const token = await authService.generateJWT(user);
        
        return new Response(JSON.stringify({
          apiKey: user.apiKey,
          token,
          tier: user.tier,
          rateLimit: {
            requests: 1000,
            period: 3600
          }
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Protected routes - require API key
      const apiKey = request.headers.get('X-API-Key') || request.headers.get('Authorization')?.replace('Bearer ', '');
      
      if (!apiKey) {
        return new Response(JSON.stringify({ error: 'API key required' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const user = await authService.getUserByApiKey(apiKey);
      if (!user) {
        return new Response(JSON.stringify({ error: 'Invalid API key' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Check rate limit
      const rateLimit = authService['getRateLimitForTier'](user.tier);
      const rateLimitCheck = await rateLimitService.checkRateLimit(
        user.id,
        rateLimit.requests,
        rateLimit.period
      );

      if (!rateLimitCheck.allowed) {
        return new Response(JSON.stringify({
          error: 'Rate limit exceeded',
          resetAt: new Date(rateLimitCheck.resetAt).toISOString(),
          tier: user.tier,
          limit: rateLimit.requests,
          period: rateLimit.period,
          suggestion: user.tier === 'anonymous' ? 
            'Register with email for higher limits' : 
            'Upgrade to pro for higher limits'
        }), {
          status: 429,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
            'X-RateLimit-Limit': rateLimit.requests.toString(),
            'X-RateLimit-Remaining': rateLimitCheck.remaining.toString(),
            'X-RateLimit-Reset': new Date(rateLimitCheck.resetAt).toISOString()
          }
        });
      }

      // Proxy Groq API requests
      if (url.pathname.startsWith('/api/groq')) {
        const response = await groqProxy.proxyRequest(request);
        
        // Add CORS and rate limit headers
        const responseHeaders = new Headers(response.headers);
        Object.entries(corsHeaders).forEach(([key, value]) => {
          responseHeaders.set(key, value);
        });
        responseHeaders.set('X-RateLimit-Limit', rateLimit.requests.toString());
        responseHeaders.set('X-RateLimit-Remaining', rateLimitCheck.remaining.toString());
        responseHeaders.set('X-RateLimit-Reset', new Date(rateLimitCheck.resetAt).toISOString());
        
        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: responseHeaders
        });
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