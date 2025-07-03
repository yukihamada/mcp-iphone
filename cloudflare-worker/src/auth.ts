import { nanoid } from 'nanoid';
import { sign, verify } from '@tsndr/cloudflare-worker-jwt';
import { Env, User, APIKeyInfo } from './types';

const JWT_SECRET = 'mcp-iphone-secret'; // In production, use env variable

export class AuthService {
  constructor(private env: Env) {}

  async createAnonymousUser(): Promise<User> {
    const user: User = {
      id: nanoid(),
      apiKey: `mcp_anon_${nanoid(32)}`,
      isVerified: false,
      createdAt: new Date().toISOString(),
      tier: 'anonymous'
    };

    await this.env.USERS.put(`user:${user.id}`, JSON.stringify(user));
    await this.env.USERS.put(`apikey:${user.apiKey}`, user.id);

    return user;
  }

  async createVerifiedUser(email: string): Promise<User> {
    const user: User = {
      id: nanoid(),
      email,
      apiKey: `mcp_${nanoid(32)}`,
      isVerified: true,
      createdAt: new Date().toISOString(),
      tier: 'free'
    };

    await this.env.USERS.put(`user:${user.id}`, JSON.stringify(user));
    await this.env.USERS.put(`apikey:${user.apiKey}`, user.id);
    await this.env.USERS.put(`email:${email}`, user.id);

    return user;
  }

  async getUserByApiKey(apiKey: string): Promise<User | null> {
    const userId = await this.env.USERS.get(`apikey:${apiKey}`);
    if (!userId) return null;

    const userJson = await this.env.USERS.get(`user:${userId}`);
    if (!userJson) return null;

    return JSON.parse(userJson);
  }

  async generateJWT(user: User): Promise<string> {
    const payload = {
      sub: user.id,
      apiKey: user.apiKey,
      tier: user.tier,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 30) // 30 days
    };

    return sign(payload, JWT_SECRET);
  }

  async verifyJWT(token: string): Promise<APIKeyInfo | null> {
    try {
      const isValid = await verify(token, JWT_SECRET);
      if (!isValid) return null;

      const payload = JSON.parse(atob(token.split('.')[1]));
      
      return {
        userId: payload.sub,
        tier: payload.tier,
        rateLimit: this.getRateLimitForTier(payload.tier)
      };
    } catch {
      return null;
    }
  }

  private getRateLimitForTier(tier: string): { requests: number; period: number } {
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