export interface Env {
  GROQ_API_KEY: string;
  USERS: KVNamespace;
  RATE_LIMITS: KVNamespace;
  DB: D1Database;
}

export interface User {
  id: string;
  email?: string;
  apiKey: string;
  isVerified: boolean;
  createdAt: string;
  tier: 'anonymous' | 'free' | 'pro';
}

export interface RateLimit {
  count: number;
  resetAt: number;
}

export interface APIKeyInfo {
  userId: string;
  tier: 'anonymous' | 'free' | 'pro';
  rateLimit: {
    requests: number;
    period: number; // in seconds
  };
}