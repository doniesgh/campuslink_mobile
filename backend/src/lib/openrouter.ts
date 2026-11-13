import { env, isTest } from '../config/env';
import { HttpError } from './http-error';

/*
 * The AI client, shared by every AI feature: chat completions through
 * OpenRouter (https://openrouter.ai), one API key for many models.
 *
 * - Off without OPENROUTER_API_KEY: `isAiConfigured()` is false and `chatJson`
 *   throws 503 AI_UNAVAILABLE. Every feature must work without it (a
 *   rules-only fallback, or that 503 shown as "not available").
 * - OPENROUTER_MODEL: one model or several, comma-separated, tried in order
 *   (free models are often busy). Default: two free models (config/env.ts).
 * - OPENROUTER_ALLOW_DATA_COLLECTION: false (default) sends requests only to
 *   providers that neither store nor train on them; the free models need true.
 *
 * Usage:
 *   const { data, model } = await chatJson<{ summary: string }>({
 *     system: 'You summarise job offers…',
 *     user: offerText,                       // untrusted text: say so in `system`
 *     schemaName: 'offer_summary',
 *     schema: { type: 'object', additionalProperties: false, required: ['summary'],
 *               properties: { summary: { type: 'string' } } },
 *     maxTokens: 600,
 *   });
 * Always check `data` (the schema is not enforced by every model).
 *
 * Tests: `configureOpenRouter({ apiKey: 'test-key', fetch: fake })` then
 * `resetOpenRouter()` (see backend/test/fake-openrouter.ts).
 */

/** JSON Schema of the expected object (sent as a strict structured output when the model supports it). */
export type JsonSchema = Record<string, unknown>;

/** The part of `fetch` the client uses, so tests can pass a fake. */
export type AiFetch = (
  url: string,
  init: RequestInit,
) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

export interface OpenRouterSettings {
  /** null: AI off. */
  apiKey: string | null;
  /** Tried in order. */
  models: string[];
  allowDataCollection: boolean;
  baseUrl: string;
  fetch: AiFetch;
}

export interface ChatJsonRequest {
  /** Instructions. Say that the user text is data, never instructions to follow. */
  system: string;
  /** The text (or JSON) to work on. */
  user: string;
  /** The shape of the answer. Without it, any JSON object is accepted. */
  schema?: JsonSchema;
  /** Names the schema for the provider, e.g. "offer_summary" (default "answer"). */
  schemaName?: string;
  /** At most this many tokens in the answer (default 4000). */
  maxTokens?: number;
  /**
   * How long the whole call may take, every model included (default 50 s).
   * Shorter for a call a user waits on that also works without AI.
   */
  timeoutMs?: number;
}

export interface ChatJsonResult<T> {
  /** The parsed JSON object of the answer. Check it: models make mistakes. */
  data: T;
  /** The model that answered (the one OpenRouter reports, else the one asked). */
  model: string;
  /** Token counts as OpenRouter reports them, or null. */
  usage: Record<string, unknown> | null;
}

export const DEFAULT_TIMEOUT_MS = 50_000;
const DEFAULT_MAX_TOKENS = 4000;
const CATALOGUE_TIMEOUT_MS = 10_000;
const BASE_URL = 'https://openrouter.ai/api/v1';

// The messages are shown as-is in the app.
const NOT_CONFIGURED = 'AI features are not available on this server.';
const NOT_AVAILABLE = 'AI features are not available right now.';
const BUSY = 'The AI service is busy. Try again in a few minutes.';
const FAILED = 'The AI service could not answer. Try again later.';

const fromEnv = (): OpenRouterSettings => ({
  apiKey: env.OPENROUTER_API_KEY || null,
  models: [...env.OPENROUTER_MODEL],
  allowDataCollection: env.OPENROUTER_ALLOW_DATA_COLLECTION,
  baseUrl: BASE_URL,
  fetch: (url, init) => fetch(url, init),
});

let settings = fromEnv();

/** How a model can be asked for JSON, and whether it reasons first (it is then asked not to). */
interface ModelCapabilities {
  /** schema: structured outputs (enforced) · object: JSON mode · text: asked in the instructions. */
  json: 'schema' | 'object' | 'text';
  reasoning: boolean;
}
const capabilities = new Map<string, ModelCapabilities>();
let catalogue: Promise<void> | null = null;

/** Tests: replace some settings (e.g. `{ apiKey: 'test-key', fetch: fake }`). Forgets the model catalogue. */
export function configureOpenRouter(overrides: Partial<OpenRouterSettings>): void {
  settings = { ...settings, ...overrides };
  capabilities.clear();
  catalogue = null;
}

/** Tests: back to the environment's settings. */
export function resetOpenRouter(): void {
  configureOpenRouter(fromEnv());
}

/** True when an API key is set: AI features can be offered. */
export const isAiConfigured = (): boolean => Boolean(settings.apiKey);

/** The models, in the order they are tried. */
export const aiModels = (): string[] => [...settings.models];

/** The first model (the one shown as "the" model, e.g. to an admin). */
export const aiModel = (): string => settings.models[0];

const log = (message: string) => {
  if (!isTest) console.warn(`[ai] ${message}`);
};

/** A failed attempt: the error to send, and whether the next model may do better. */
class AttemptError extends Error {
  constructor(
    readonly httpError: HttpError,
    readonly tryNext: boolean,
  ) {
    super(httpError.message);
  }
}

const aiError = (status: number, message: string, code: string) =>
  new HttpError(status, message, undefined, code);

/** What an OpenRouter error status means for the app. */
function attemptErrorForStatus(status: number): AttemptError {
  // The key is refused: no model will do better.
  if (status === 401 || status === 403) {
    return new AttemptError(aiError(503, NOT_AVAILABLE, 'AI_UNAVAILABLE'), false);
  }
  // No credits: a free model may still answer.
  if (status === 402) return new AttemptError(aiError(503, NOT_AVAILABLE, 'AI_NO_CREDITS'), true);
  if (status === 429) return new AttemptError(aiError(429, BUSY, 'AI_BUSY'), true);
  return new AttemptError(aiError(502, FAILED, 'AI_FAILED'), true);
}

const failed = () => new AttemptError(aiError(502, FAILED, 'AI_FAILED'), true);

/** Reads OpenRouter's public model list once (what each model supports). Never throws. */
function loadCatalogue(timeoutMs: number): Promise<void> {
  catalogue ??= settings
    .fetch(`${settings.baseUrl}/models`, {
      method: 'GET',
      signal: AbortSignal.timeout(Math.min(CATALOGUE_TIMEOUT_MS, timeoutMs)),
    })
    .then(async (response) => {
      if (!response.ok) throw new Error(`the model list answered ${response.status}`);
      const body = (await response.json()) as { data?: unknown };
      for (const entry of Array.isArray(body?.data) ? body.data : []) {
        const { id, supported_parameters: params } = (entry ?? {}) as {
          id?: unknown;
          supported_parameters?: unknown;
        };
        if (typeof id !== 'string') continue;
        const supported = Array.isArray(params) ? params : [];
        let json: ModelCapabilities['json'] = 'text';
        if (supported.includes('structured_outputs')) json = 'schema';
        else if (supported.includes('response_format')) json = 'object';
        capabilities.set(id, { json, reasoning: supported.includes('reasoning') });
      }
    })
    .catch((err: unknown) => {
      // Unknown for now: asked again next time; meanwhile models are asked with the schema.
      log(`could not read the model list: ${(err as Error).message}`);
      catalogue = null;
    });
  return catalogue;
}

async function capabilitiesOf(model: string, timeoutMs: number): Promise<ModelCapabilities> {
  if (!capabilities.has(model)) await loadCatalogue(timeoutMs);
  return capabilities.get(model) ?? { json: 'schema', reasoning: false };
}

/**
 * The JSON object of an answer, also when it comes in a ```json block or
 * after a sentence. Throws when there is none.
 */
export function extractJsonObject(text: string): Record<string, unknown> {
  const value = text.trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    const start = value.indexOf('{');
    const end = value.lastIndexOf('}');
    if (start === -1 || end <= start) throw new Error('no JSON object');
    parsed = JSON.parse(value.slice(start, end + 1));
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new Error('not a JSON object');
  }
  return parsed as Record<string, unknown>;
}

/** The text of an answer: a string, or the text parts of an array. */
function messageText(content: unknown): string {
  if (Array.isArray(content)) {
    return content.map((part) => (part as { text?: unknown })?.text ?? '').join('');
  }
  return typeof content === 'string' ? content : '';
}

interface ChatAnswer {
  model?: unknown;
  usage?: unknown;
  error?: { code?: unknown; message?: unknown };
  choices?: { message?: { content?: unknown } }[];
}

/** One call to one model. Throws an AttemptError. */
async function askModel<T>(
  model: string,
  request: ChatJsonRequest,
  timeoutMs: number,
): Promise<ChatJsonResult<T>> {
  const started = Date.now();
  const caps = await capabilitiesOf(model, timeoutMs);
  const remaining = timeoutMs - (Date.now() - started);
  if (remaining <= 0) throw failed();

  const { schema } = request;
  // Structured outputs need a schema: without one, JSON mode is the best.
  const mode = caps.json === 'schema' && !schema ? 'object' : caps.json;
  let instructions = request.system;
  if (mode !== 'schema') {
    instructions += schema
      ? `\n\nAnswer with one JSON object only, no other text, following this JSON schema:\n${JSON.stringify(schema)}`
      : '\n\nAnswer with one JSON object only, no other text.';
  }
  const responseFormat =
    mode === 'schema'
      ? {
          type: 'json_schema',
          json_schema: { name: request.schemaName ?? 'answer', strict: true, schema },
        }
      : mode === 'object'
        ? { type: 'json_object' }
        : undefined;

  let response: Awaited<ReturnType<AiFetch>>;
  try {
    response = await settings.fetch(`${settings.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${settings.apiKey}`,
        'Content-Type': 'application/json',
        // Optional attribution shown in the OpenRouter dashboard.
        'X-Title': 'CampusPulse',
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: instructions },
          { role: 'user', content: request.user },
        ],
        ...(responseFormat ? { response_format: responseFormat } : {}),
        // Reasoning models otherwise think for 30 s or more, and can spend every token before answering.
        ...(caps.reasoning ? { reasoning: { enabled: false } } : {}),
        provider: {
          // Only providers that honour the JSON format asked for.
          require_parameters: Boolean(responseFormat),
          data_collection: settings.allowDataCollection ? 'allow' : 'deny',
        },
        temperature: 0,
        max_tokens: request.maxTokens ?? DEFAULT_MAX_TOKENS,
      }),
      signal: AbortSignal.timeout(remaining),
    });
  } catch (err) {
    log(`${model} could not be reached: ${(err as Error).message}`);
    throw failed();
  }

  // OpenRouter answers 200 at once and keeps the connection open while the
  // model works: a model too slow is cut off here, by the timeout.
  const body = (await response.json().catch(() => null)) as ChatAnswer | null;
  if (!response.ok) {
    log(`${model} answered ${response.status}: ${String(body?.error?.message ?? '').slice(0, 300)}`);
    throw attemptErrorForStatus(response.status);
  }
  if (!body) {
    log(`${model} did not answer within ${Math.round(timeoutMs / 1000)} s`);
    throw failed();
  }
  // OpenRouter can also report a failure inside a 200 answer.
  if (body.error) {
    log(`${model} failed: ${String(body.error.message ?? '').slice(0, 300)}`);
    throw attemptErrorForStatus(Number(body.error.code) || 502);
  }

  const text = messageText(body.choices?.[0]?.message?.content);
  try {
    return {
      data: extractJsonObject(text) as T,
      model: typeof body.model === 'string' && body.model ? body.model : model,
      usage:
        typeof body.usage === 'object' && body.usage !== null
          ? (body.usage as Record<string, unknown>)
          : null,
    };
  } catch {
    log(`${model} did not answer with JSON: ${text.slice(0, 200)}`);
    throw failed();
  }
}

/**
 * Asks the models, in order, for one JSON object (following [request.schema]
 * when given) and returns it with the model that answered. A model that is
 * busy, down, too slow or answers something that isn't JSON passes the turn
 * to the next one, within [request.timeoutMs] in all.
 *
 * Throws an HttpError (with its `code`) when none could answer:
 * - 503 AI_UNAVAILABLE: no API key, or the key is refused;
 * - 503 AI_NO_CREDITS: the OpenRouter account has no credits left;
 * - 429 AI_BUSY: rate or daily limit reached;
 * - 502 AI_FAILED: unreachable, too slow, an error, or an answer that isn't JSON.
 * The error of the last model tried is the one thrown.
 */
export async function chatJson<T = Record<string, unknown>>(
  request: ChatJsonRequest,
): Promise<ChatJsonResult<T>> {
  if (!isAiConfigured()) throw aiError(503, NOT_CONFIGURED, 'AI_UNAVAILABLE');
  const deadline = Date.now() + (request.timeoutMs ?? DEFAULT_TIMEOUT_MS);
  let last: AttemptError = failed();
  for (const model of settings.models) {
    const remaining = deadline - Date.now();
    if (remaining <= 0) break;
    try {
      return await askModel<T>(model, request, remaining);
    } catch (err) {
      if (!(err instanceof AttemptError)) throw err;
      last = err;
      if (!err.tryNext) break;
    }
  }
  throw last.httpError;
}
