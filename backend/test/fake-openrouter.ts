import { configureOpenRouter, type AiFetch } from '../src/lib/openrouter';

/** One queued answer of the fake chat endpoint. */
type FakeAnswer =
  | { kind: 'json'; content: unknown; model?: string }
  | { kind: 'text'; text: string }
  | { kind: 'status'; status: number; message: string }
  | { kind: 'body'; status: number; body: unknown }
  | { kind: 'network'; error: Error };

export interface FakeOpenRouter {
  fetch: AiFetch;
  /** The chat requests received, in order: the model asked and the parsed JSON body. */
  requests: { model: string; body: Record<string, unknown> }[];
  /** How many times the model list was read. */
  catalogueReads: number;
  /** What `/models` says each model supports (`supported_parameters`). Default: structured outputs. */
  catalogue: Record<string, string[]>;
  /** The next chat call answers this object as its JSON content (from [model], else the model asked). */
  replyJson(content: unknown, model?: string): FakeOpenRouter;
  /** The next chat call answers this text as its content. */
  replyText(text: string): FakeOpenRouter;
  /** The next chat call answers this HTTP error status. */
  replyStatus(status: number, message?: string): FakeOpenRouter;
  /** The next chat call answers this raw JSON body (e.g. a 200 with an `error`). */
  replyBody(body: unknown, status?: number): FakeOpenRouter;
  /** The next chat call fails like an unreachable server. */
  failNetwork(error?: Error): FakeOpenRouter;
}

const response = (status: number, body: unknown) => ({
  ok: status >= 200 && status < 300,
  status,
  json: async () => body,
});

/**
 * A stand-in for OpenRouter. Unanswered calls get a 500. Turn it on for the
 * code under test with [useFakeOpenRouter], and call `resetOpenRouter()`
 * afterwards:
 *
 *   const ai = useFakeOpenRouter();
 *   ai.replyJson({ summary: 'A 6-month Flutter internship.' });
 *   ... call the route ...
 *   expect(ai.requests[0].body.max_tokens).toBe(600);
 */
export function fakeOpenRouter(): FakeOpenRouter {
  const answers: FakeAnswer[] = [];
  const fake: FakeOpenRouter = {
    requests: [],
    catalogueReads: 0,
    catalogue: {},
    async fetch(url, init) {
      if (url.endsWith('/models')) {
        fake.catalogueReads += 1;
        return response(200, {
          data: Object.entries(fake.catalogue).map(([id, params]) => ({
            id,
            supported_parameters: params,
          })),
        });
      }
      const body = JSON.parse(String(init.body)) as Record<string, unknown>;
      const model = String(body.model);
      fake.requests.push({ model, body });
      const answer = answers.shift();
      if (!answer) return response(500, { error: { message: 'No fake answer queued' } });
      switch (answer.kind) {
        case 'network':
          throw answer.error;
        case 'status':
          return response(answer.status, { error: { code: answer.status, message: answer.message } });
        case 'body':
          return response(answer.status, answer.body);
        case 'text':
          return response(200, { model, choices: [{ message: { content: answer.text } }] });
        case 'json':
          return response(200, {
            model: answer.model ?? model,
            choices: [{ message: { content: JSON.stringify(answer.content) } }],
            usage: { prompt_tokens: 12, completion_tokens: 8, total_tokens: 20 },
          });
      }
    },
    replyJson(content, model) {
      answers.push({ kind: 'json', content, model });
      return fake;
    },
    replyText(text) {
      answers.push({ kind: 'text', text });
      return fake;
    },
    replyStatus(status, message = `Fake error ${status}`) {
      answers.push({ kind: 'status', status, message });
      return fake;
    },
    replyBody(body, status = 200) {
      answers.push({ kind: 'body', status, body });
      return fake;
    },
    failNetwork(error = new TypeError('fetch failed')) {
      answers.push({ kind: 'network', error });
      return fake;
    },
  };
  return fake;
}

/**
 * Turns AI on with a fake OpenRouter (key "test-key", [models] tried in that
 * order) and returns the fake. Call `resetOpenRouter()` after the test.
 */
export function useFakeOpenRouter(models = ['test/model-a', 'test/model-b']): FakeOpenRouter {
  const fake = fakeOpenRouter();
  configureOpenRouter({ apiKey: 'test-key', models, allowDataCollection: false, fetch: fake.fetch });
  return fake;
}
