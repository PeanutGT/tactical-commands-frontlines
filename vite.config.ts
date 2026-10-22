import { defineConfig } from 'vitest/config';

export default defineConfig({
  base: './',
  server: { host: true },
  // Phaser alone is ~1.2 MB minified.
  build: { chunkSizeWarningLimit: 1600 },
  test: {
    include: ['tests/**/*.test.ts'],
    environment: 'node',
  },
});
