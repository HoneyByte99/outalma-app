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

  // Coverage collection. Budget line T5b requires 80% on the files an increment
  // adds or modifies, which cannot be measured without collecting in the first
  // place. Per-path thresholds are declared alongside the files they guard, as
  // jest fails outright on a threshold pointing at a path with no coverage data.
  collectCoverage: true,
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
  coverageDirectory: 'coverage',
  coverageReporters: ['text-summary', 'lcov'],

  // Budget line T5b: 80% on the files this increment adds. Declared per path,
  // because a global bar on a 2600-line entrypoint would say nothing about the
  // new code. The modified ranges of index.ts are measured separately, against
  // the diff, since jest thresholds cannot express line ranges.
  coverageThreshold: {
    './src/identity_extraction.ts': {
      lines: 80,
      branches: 80,
      functions: 80,
      statements: 80,
    },
  },
};
