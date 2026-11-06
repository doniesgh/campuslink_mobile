/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.json' }] },
  // Sets NODE_ENV, secrets and a per-worker test database before any import.
  setupFiles: ['<rootDir>/test/setup-env.ts'],
  testTimeout: 20000,
};
