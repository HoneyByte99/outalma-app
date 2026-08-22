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
  // Coverage collection. Two budget lines apply: the grille's 25% global floor
  // (T5a/T5b, added with the functions test suite) and the 80% bar on the files
  // an increment adds or modifies (T5b). Per-path thresholds are declared
  // alongside the files they guard, as jest fails outright on a threshold
  // pointing at a path with no coverage data.
  collectCoverage: true,
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
  coverageDirectory: 'coverage',
  coverageReporters: ['text-summary', 'lcov'],
  coverageThreshold: {
    global: { statements: 25, branches: 25, functions: 25, lines: 25 },
    './src/identity_verification.ts': {
      lines: 80,
      branches: 80,
      functions: 80,
      statements: 80,
    },
    './src/identity_extraction.ts': {
      lines: 80,
      branches: 80,
      functions: 80,
      statements: 80,
    },
  },
};
