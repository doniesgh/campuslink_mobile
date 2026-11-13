import { config } from 'dotenv';
import { z } from 'zod';

config({ quiet: true });

/**
 * The OpenRouter models used when OPENROUTER_MODEL is empty: free ones (50
 * requests a day without credits), the first tried first. They need
 * OPENROUTER_ALLOW_DATA_COLLECTION=true.
 */
export const DEFAULT_OPENROUTER_MODELS = [
  'nvidia/nemotron-3.5-lightning:free',
  'google/gemma-4-31b-it:free',
];

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
  /**
   * How many proxies sit in front of the API (Render: 1). Their
   * X-Forwarded-For header then gives the real client IP, for the rate
   * limits and the audit log. 0 (the default) when the API is reached directly.
   */
  TRUST_PROXY: z.coerce.number().int().min(0).default(0),

  // Email. Without SMTP_HOST, emails are printed in the console instead.
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().int().positive().default(587),
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  SMTP_FROM: z.string().default('CampusPulse <no-reply@campuspulse.test>'),
  /**
   * Gmail through Google Apps Script (backend/mail-relay/gmail-relay.gs): the
   * web app's URL and the secret it checks. Sends over HTTPS, so it works where
   * SMTP ports are blocked (Render's free plan). Takes precedence over SMTP.
   */
  MAIL_RELAY_URL: z
    .string()
    .trim()
    .refine((url) => url === '' || url.startsWith('https://'), 'MAIL_RELAY_URL must start with https://')
    .optional(),
  MAIL_RELAY_SECRET: z.string().trim().optional(),

  // Push notifications. Without FIREBASE_SERVICE_ACCOUNT_FILE, push is off.
  FIREBASE_SERVICE_ACCOUNT_FILE: z.string().trim().optional(),

  // AI through OpenRouter (lib/openrouter.ts). Without OPENROUTER_API_KEY, AI is off.
  OPENROUTER_API_KEY: z.string().trim().optional(),
  /** One model, or several separated by commas: tried in order (free models are often busy). */
  OPENROUTER_MODEL: z
    .string()
    .trim()
    .optional()
    .transform((value) => {
      const models = (value ?? '')
        .split(',')
        .map((model) => model.trim())
        .filter(Boolean);
      return models.length > 0 ? models : DEFAULT_OPENROUTER_MODELS;
    }),
  /**
   * false (default): only providers that neither store nor train on what is
   * sent. The free models need true.
   */
  OPENROUTER_ALLOW_DATA_COLLECTION: z.preprocess(
    (value) => (typeof value === 'string' && value.trim() === '' ? undefined : value),
    z
      .stringbool({ error: 'OPENROUTER_ALLOW_DATA_COLLECTION must be true or false' })
      .default(false),
  ),
}).refine(
  (vars) => !vars.MAIL_RELAY_URL || (vars.MAIL_RELAY_SECRET ?? '').length >= 16,
  { path: ['MAIL_RELAY_SECRET'], message: 'MAIL_RELAY_SECRET (at least 16 characters) is required with MAIL_RELAY_URL' },
);

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error(`Invalid environment variables:\n${z.prettifyError(parsed.error)}`);
  process.exit(1);
}

export const env = parsed.data;
export const isProd = env.NODE_ENV === 'production';
export const isTest = env.NODE_ENV === 'test';
