module.exports = {
    preset: 'ts-jest',
    testEnvironment: 'node',
    // Only run the TypeScript tests under src/. This keeps jest from picking up
    // the compiled dist/**/*.test.js files (where jest.mock is no longer hoisted
    // above the imports, so the real PrismaClient loads and tries to reach a DB).
    roots: ['<rootDir>/src'],
    testPathIgnorePatterns: ['/node_modules/', '/dist/'],
  };