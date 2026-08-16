import { enhancedImages } from '@sveltejs/enhanced-img';
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { svelteTesting } from '@testing-library/svelte/vite';
import { visualizer } from 'rollup-plugin-visualizer';
import { defineConfig, type UserConfig } from 'vite';
import path from 'node:path';
import { proxy } from './vite-proxy';

export default defineConfig({
  build: {
    target: 'es2022',
  },
  resolve: {
    alias: {
      'xmlhttprequest-ssl': './node_modules/engine.io-client/lib/xmlhttprequest.js',
      // eslint-disable-next-line unicorn/prefer-module
      '@test-data': path.resolve(__dirname, './src/test-data'),
      // '@immich/ui': path.resolve(__dirname, '../../ui/packages/ui'),
    },
  },
  server: {
    // connect to a remote backend during web-only development
    proxy,
    allowedHosts: true,
  },
  preview: {
    proxy,
  },
  plugins: [
    enhancedImages(),
    tailwindcss(),
    sveltekit(),
    process.env.BUILD_STATS === 'true'
      ? visualizer({
          emitFile: true,
          filename: 'stats.html',
        })
      : undefined,
    svelteTesting(),
  ],
  optimizeDeps: {
    entries: ['src/**/*.{svelte,ts,html}'],
  },
  test: {
    name: 'web:unit',
    include: ['src/**/*.{test,spec}.{js,ts}'],
    globals: true,
    environment: 'happy-dom',
    setupFiles: ['./src/test-data/setup.ts'],
    sequence: {
      hooks: 'list',
    },
    env: {
      TZ: 'UTC',
    },
  },
} as UserConfig);
