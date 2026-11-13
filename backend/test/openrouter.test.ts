import { DEFAULT_OPENROUTER_MODELS, env } from '../src/config/env';
import {
  aiModel,
  aiModels,
  chatJson,
  configureOpenRouter,
  extractJsonObject,
  isAiConfigured,
  resetOpenRouter,
} from '../src/lib/openrouter';
import { fakeOpenRouter, useFakeOpenRouter } from './fake-openrouter';

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary'],
  properties: { summary: { type: 'string' } },
};

const ask = (overrides: Partial<Parameters<typeof chatJson>[0]> = {}) =>
  chatJson<{ summary: string }>({
    system: 'Summarise the offer.',
    user: 'A 6-month Flutter internship in Tunis.',
    schemaName: 'offer_summary',
    schema: SCHEMA,
    ...overrides,
  });

afterEach(resetOpenRouter);

describe('settings', () => {
  test('AI is off without a key (the test environment has none)', async () => {
    expect(env.OPENROUTER_API_KEY).toBeFalsy();
    expect(isAiConfigured()).toBe(false);
    await expect(ask()).rejects.toMatchObject({
      status: 503,
      code: 'AI_UNAVAILABLE',
      message: 'AI features are not available on this server.',
    });
  });

  test('the default models are the free ones, without data collection', () => {
    expect(env.OPENROUTER_MODEL).toEqual(DEFAULT_OPENROUTER_MODELS);
    expect(aiModels()).toEqual(DEFAULT_OPENROUTER_MODELS);
    expect(aiModel()).toBe('nvidia/nemotron-3.5-lightning:free');
    expect(env.OPENROUTER_ALLOW_DATA_COLLECTION).toBe(false);
  });

  test('configureOpenRouter turns AI on; resetOpenRouter goes back to the environment', () => {
    configureOpenRouter({ apiKey: 'k', models: ['a/b'] });
    expect(isAiConfigured()).toBe(true);
    expect(aiModel()).toBe('a/b');
    resetOpenRouter();
    expect(isAiConfigured()).toBe(false);
  });
});

describe('chatJson', () => {
  test('asks the first model for a strict JSON schema and returns the parsed answer', async () => {
    const ai = useFakeOpenRouter();
    ai.replyJson({ summary: 'A Flutter internship.' }, 'test/model-a-2026');

    const result = await ask({ maxTokens: 600 });

    expect(result).toEqual({
      data: { summary: 'A Flutter internship.' },
      model: 'test/model-a-2026',
      usage: { prompt_tokens: 12, completion_tokens: 8, total_tokens: 20 },
    });
    expect(ai.requests).toHaveLength(1);
    expect(ai.requests[0].body).toEqual({
      model: 'test/model-a',
      messages: [
        { role: 'system', content: 'Summarise the offer.' },
        { role: 'user', content: 'A 6-month Flutter internship in Tunis.' },
      ],
      response_format: {
        type: 'json_schema',
        json_schema: { name: 'offer_summary', strict: true, schema: SCHEMA },
      },
      provider: { require_parameters: true, data_collection: 'deny' },
      temperature: 0,
      max_tokens: 600,
    });
  });

  test('sends the key and allows data collection when configured', async () => {
    const ai = fakeOpenRouter().replyJson({ summary: 'ok' });
    const calls: RequestInit[] = [];
    configureOpenRouter({
      apiKey: 'sk-or-test',
      models: ['m/one'],
      allowDataCollection: true,
      fetch: (url, init) => {
        calls.push(init);
        return ai.fetch(url, init);
      },
    });
    await ask();
    const chat = calls.find((init) => init.method === 'POST') as RequestInit;
    expect(chat.headers).toMatchObject({ Authorization: 'Bearer sk-or-test', 'X-Title': 'CampusPulse' });
    expect(ai.requests[0].body.provider).toEqual({ require_parameters: true, data_collection: 'allow' });
    expect(ai.requests[0].body.max_tokens).toBe(4000);
  });

  test('follows what the model list says the model supports', async () => {
    const ai = useFakeOpenRouter(['free/json-mode', 'free/text-only']);
    ai.catalogue = {
      'free/json-mode': ['response_format', 'reasoning'],
      'free/text-only': [],
    };
    ai.replyJson({ summary: 'one' });
    await ask();
    const jsonMode = ai.requests[0].body;
    expect(jsonMode.response_format).toEqual({ type: 'json_object' });
    expect(jsonMode.reasoning).toEqual({ enabled: false });
    const system = (jsonMode.messages as { content: string }[])[0].content;
    expect(system).toContain('Answer with one JSON object only');
    expect(system).toContain('"summary"');

    // A model that only writes text: the answer may wrap the JSON in prose or a code block.
    configureOpenRouter({ models: ['free/text-only'] });
    ai.catalogue = { 'free/text-only': [] };
    ai.replyText('Sure! ```json\n{"summary":"two"}\n```');
    const result = await ask();
    expect(result.data).toEqual({ summary: 'two' });
    const textOnly = ai.requests[1].body;
    expect(textOnly.response_format).toBeUndefined();
    expect(textOnly.provider).toEqual({ require_parameters: false, data_collection: 'deny' });
    // The model list was read once per configuration.
    expect(ai.catalogueReads).toBe(2);
  });

  test('without a schema, asks for any JSON object', async () => {
    const ai = useFakeOpenRouter(['m/structured']);
    ai.catalogue = { 'm/structured': ['structured_outputs', 'response_format'] };
    ai.replyJson({ anything: true });
    const result = await chatJson({ system: 'Answer.', user: 'Hi' });
    expect(result.data).toEqual({ anything: true });
    expect(ai.requests[0].body.response_format).toEqual({ type: 'json_object' });
  });

  test.each([
    ['busy (429)', (ai: ReturnType<typeof fakeOpenRouter>) => ai.replyStatus(429)],
    ['down (503)', (ai: ReturnType<typeof fakeOpenRouter>) => ai.replyStatus(503)],
    ['out of credits (402)', (ai: ReturnType<typeof fakeOpenRouter>) => ai.replyStatus(402)],
    ['unreachable', (ai: ReturnType<typeof fakeOpenRouter>) => ai.failNetwork()],
    ['not JSON', (ai: ReturnType<typeof fakeOpenRouter>) => ai.replyText('I cannot help.')],
    ['a JSON array', (ai: ReturnType<typeof fakeOpenRouter>) => ai.replyText('[1, 2]')],
    ['an error in a 200', (ai: ReturnType<typeof fakeOpenRouter>) =>
      ai.replyBody({ error: { code: 502, message: 'Provider returned error' } })],
  ])('passes the turn to the next model when the first is %s', async (_name, fail) => {
    const ai = useFakeOpenRouter();
    fail(ai);
    ai.replyJson({ summary: 'from b' });

    const result = await ask();

    expect(result).toMatchObject({ data: { summary: 'from b' }, model: 'test/model-b' });
    expect(ai.requests.map((r) => r.model)).toEqual(['test/model-a', 'test/model-b']);
  });

  test.each([
    [429, 429, 'AI_BUSY', 'The AI service is busy. Try again in a few minutes.'],
    [402, 503, 'AI_NO_CREDITS', 'AI features are not available right now.'],
    [500, 502, 'AI_FAILED', 'The AI service could not answer. Try again later.'],
  ])('when every model fails with %i, throws %i %s', async (upstream, status, code, message) => {
    const ai = useFakeOpenRouter();
    ai.replyStatus(503).replyStatus(upstream);
    await expect(ask()).rejects.toMatchObject({ status, code, message });
    expect(ai.requests).toHaveLength(2);
  });

  test('a refused key stops at once: no other model can do better', async () => {
    const ai = useFakeOpenRouter();
    ai.replyStatus(401);
    await expect(ask()).rejects.toMatchObject({ status: 503, code: 'AI_UNAVAILABLE' });
    expect(ai.requests).toHaveLength(1);
  });

  test('an answer that never comes is cut off by the timeout', async () => {
    const ai = fakeOpenRouter();
    configureOpenRouter({
      apiKey: 'k',
      models: ['slow/model'],
      fetch: async (url, init) => {
        if (url.endsWith('/models')) return ai.fetch(url, init);
        // Like OpenRouter: the call ends only when the timeout aborts it.
        return new Promise((_resolve, reject) => {
          init.signal?.addEventListener('abort', () => reject(init.signal?.reason));
        });
      },
    });
    const started = Date.now();
    await expect(ask({ timeoutMs: 200 })).rejects.toMatchObject({ status: 502, code: 'AI_FAILED' });
    expect(Date.now() - started).toBeLessThan(5_000);
  });

  test('a 200 whose body never arrives is cut off too', async () => {
    const ai = fakeOpenRouter();
    configureOpenRouter({
      apiKey: 'k',
      models: ['slow/model'],
      fetch: async (url, init) => {
        if (url.endsWith('/models')) return ai.fetch(url, init);
        return { ok: true, status: 200, json: () => Promise.reject(new Error('aborted')) };
      },
    });
    await expect(ask()).rejects.toMatchObject({ status: 502, code: 'AI_FAILED' });
  });

  test('a model list that cannot be read is retried later; the models are asked with the schema', async () => {
    const ai = useFakeOpenRouter(['m/one']);
    let reads = 0;
    configureOpenRouter({
      fetch: async (url, init) => {
        if (url.endsWith('/models')) {
          reads += 1;
          return { ok: false, status: 500, json: async () => ({}) };
        }
        return ai.fetch(url, init);
      },
    });
    ai.replyJson({ summary: 'a' }).replyJson({ summary: 'b' });
    await ask();
    await ask();
    expect(reads).toBe(2);
    expect((ai.requests[0].body.response_format as { type: string }).type).toBe('json_schema');
  });
});

test('extractJsonObject finds the object in an answer', () => {
  expect(extractJsonObject('{"a":1}')).toEqual({ a: 1 });
  expect(extractJsonObject('Here it is:\n```json\n{"a":{"b":[1]}}\n```')).toEqual({ a: { b: [1] } });
  expect(() => extractJsonObject('no json')).toThrow();
  expect(() => extractJsonObject('"text"')).toThrow();
  expect(() => extractJsonObject('null')).toThrow();
});
