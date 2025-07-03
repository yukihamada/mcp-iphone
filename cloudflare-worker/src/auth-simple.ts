import { nanoid } from 'nanoid';
import { Env, User, APIKeyInfo } from './types';

export class SimpleAuthService {
  constructor(private env: Env) {}

  // Simple in-memory auth for demo purposes
  createAnonymousUser(): User {
    return {
      id: nanoid(),
      apiKey: `mcp_anon_${nanoid(32)}`,
      isVerified: false,
      createdAt: new Date().toISOString(),
      tier: 'anonymous'
    };
  }

  createVerifiedUser(email: string): User {
    return {
      id: nanoid(),
      email,
      apiKey: `mcp_${nanoid(32)}`,
      isVerified: true,
      createdAt: new Date().toISOString(),
      tier: 'free'
    };
  }

  // For demo, just validate API key format
  async validateApiKey(apiKey: string): Promise<APIKeyInfo | null> {
    if (!apiKey) return null;
    
    if (apiKey.startsWith('mcp_anon_')) {
      return {
        userId: 'anonymous',
        tier: 'anonymous',
        rateLimit: { requests: 10, period: 3600 }
      };
    } else if (apiKey.startsWith('mcp_')) {
      return {
        userId: 'verified',
        tier: 'free',
        rateLimit: { requests: 1000, period: 3600 }
      };
    }
    
    return null;
  }

  getRateLimitForTier(tier: string): { requests: number; period: number } {
    switch (tier) {
      case 'anonymous':
        return { requests: 10, period: 3600 }; // 10 requests per hour
      case 'free':
        return { requests: 1000, period: 3600 }; // 1000 requests per hour
      case 'pro':
        return { requests: 10000, period: 3600 }; // 10000 requests per hour
      default:
        return { requests: 10, period: 3600 };
    }
  }
}