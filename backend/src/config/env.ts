import { config } from 'dotenv';
import { z } from 'zod';

config({ quiet: true });

/** Environment variables, validated once at startup. See .env.example. */
const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  HOST: z.string().default('127.0.0.1'),
  MONGO_URL: z.string().min(1).default('mongodb://127.0.0.1:27017/campuspulse'),
  JWT_ACCESS_SECRET: z
    .string({ error: 'JWT_ACCESS_SECRET is required (see .env.example)' })
    .min(32, 'JWT_ACCESS_SECRET must be at least 32 characters'),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(15 * 60),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  CORS_ORIGIN: z.string().default('*'),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error(`Invalid environment variables:\n${z.prettifyError(parsed.error)}`);
  process.exit(1);
}

export const env = parsed.data;
export const isProd = env.NODE_ENV === 'production';
export const isTest = env.NODE_ENV === 'test';
