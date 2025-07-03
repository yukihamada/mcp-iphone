import { Env } from './types';

export class GroqProxyService {
  private readonly GROQ_API_URL = 'https://api.groq.com/openai/v1';

  constructor(private env: Env) {}

  async proxyRequest(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname.replace('/api/groq', '');
    
    const groqUrl = `${this.GROQ_API_URL}${path}`;
    
    const headers = new Headers(request.headers);
    headers.set('Authorization', `Bearer ${this.env.GROQ_API_KEY}`);
    headers.delete('X-API-Key'); // Remove client API key
    
    try {
      const groqResponse = await fetch(groqUrl, {
        method: request.method,
        headers,
        body: request.method !== 'GET' ? await request.text() : undefined,
      });

      const responseHeaders = new Headers(groqResponse.headers);
      responseHeaders.set('X-Powered-By', 'MCP-iPhone-Gateway');
      
      return new Response(groqResponse.body, {
        status: groqResponse.status,
        statusText: groqResponse.statusText,
        headers: responseHeaders,
      });
    } catch (error) {
      return new Response(JSON.stringify({
        error: 'Failed to proxy request to Groq',
        details: error instanceof Error ? error.message : 'Unknown error'
      }), {
        status: 502,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }

  async streamCompletion(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname.replace('/api/groq', '');
    const groqUrl = `${this.GROQ_API_URL}${path}`;
    
    const headers = new Headers(request.headers);
    headers.set('Authorization', `Bearer ${this.env.GROQ_API_KEY}`);
    headers.delete('X-API-Key');
    
    const groqResponse = await fetch(groqUrl, {
      method: request.method,
      headers,
      body: await request.text(),
    });

    if (!groqResponse.ok) {
      return groqResponse;
    }

    // Handle SSE streaming
    const { readable, writable } = new TransformStream();
    const writer = writable.getWriter();
    const encoder = new TextEncoder();

    groqResponse.body?.pipeTo(new WritableStream({
      async write(chunk) {
        await writer.write(chunk);
      },
      async close() {
        await writer.close();
      },
      async abort(err) {
        await writer.abort(err);
      }
    }));

    return new Response(readable, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'X-Powered-By': 'MCP-iPhone-Gateway'
      }
    });
  }
}