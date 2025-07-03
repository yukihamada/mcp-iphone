import { Env, RateLimit } from './types';

export class RateLimitService {
  constructor(private env: Env) {}

  async checkRateLimit(
    userId: string, 
    limit: number, 
    period: number
  ): Promise<{ allowed: boolean; remaining: number; resetAt: number }> {
    const key = `ratelimit:${userId}`;
    const now = Date.now();
    
    const data = await this.env.RATE_LIMITS.get(key);
    let rateLimit: RateLimit = data ? JSON.parse(data) : { count: 0, resetAt: now + period * 1000 };

    // Reset if period has passed
    if (now > rateLimit.resetAt) {
      rateLimit = { count: 0, resetAt: now + period * 1000 };
    }

    const allowed = rateLimit.count < limit;
    const remaining = Math.max(0, limit - rateLimit.count - 1);

    if (allowed) {
      rateLimit.count++;
      await this.env.RATE_LIMITS.put(key, JSON.stringify(rateLimit), {
        expirationTtl: period
      });
    }

    return {
      allowed,
      remaining,
      resetAt: rateLimit.resetAt
    };
  }

  async resetUserLimit(userId: string): Promise<void> {
    const key = `ratelimit:${userId}`;
    await this.env.RATE_LIMITS.delete(key);
  }
}