// Runs before each test file (jest `setupFiles`), before any import reads the
// environment. Each Jest worker gets its own throwaway database; set
// TEST_DB_PREFIX to keep two simultaneous test runs apart.
process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-that-is-long-enough-0123456789';
process.env.MONGO_URL =
  process.env.MONGO_URL_TEST ??
  `mongodb://127.0.0.1:27017/${process.env.TEST_DB_PREFIX ?? 'campuspulse_test'}_${
    process.env.JEST_WORKER_ID ?? '0'
  }`;
// AI is off in tests, whatever backend/.env says (dotenv never overrides a
// variable that is already set): a test turns it on with a fake OpenRouter
// (test/fake-openrouter.ts), never the real one.
process.env.OPENROUTER_API_KEY = '';
process.env.OPENROUTER_MODEL = '';
process.env.OPENROUTER_ALLOW_DATA_COLLECTION = '';
