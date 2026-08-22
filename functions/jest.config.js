/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  transform: {
    '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.test.json' }],
  },
  // Transactions against the Firestore emulator are not instant; give them room.
  testTimeout: 20000,
  // Emulator state is shared; run serially so beforeEach clears don't race.
  maxWorkers: 1,
  // Coverage. functions/ carried no coverage measurement before this increment
  // (grille de budgets T5a/T5b). Collected only when --coverage is passed
  // (see the test:coverage script) so the ordinary emulator run stays fast; the
  // threshold is the grille's 25% global floor. Raise it as the suite grows.
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
  coverageThreshold: {
    global: { statements: 25, branches: 25, functions: 25, lines: 25 },
  },
};
