// Runs before each test file (jest `setupFiles`), before any import reads the
// environment. Each Jest worker gets its own throwaway database.
process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-that-is-long-enough-0123456789';
process.env.MONGO_URL =
  process.env.MONGO_URL_TEST ??
  `mongodb://127.0.0.1:27017/campuspulse_test_${process.env.JEST_WORKER_ID ?? '0'}`;
