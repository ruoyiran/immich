import { defineConfig, devices, PlaywrightTestConfig } from '@playwright/test';
import dotenv from 'dotenv';
import { cpus } from 'node:os';
import { resolve } from 'node:path';

dotenv.config({ quiet: true, path: resolve(import.meta.dirname, '.env') });
process.env.TZ = 'UTC';

export const playwrightHost = process.env.PLAYWRIGHT_HOST ?? '127.0.0.1';
export const playwriteBaseUrl = process.env.PLAYWRIGHT_BASE_URL ?? `http://${playwrightHost}:2285`;
export const playwriteSlowMo = Number.parseInt(process.env.PLAYWRIGHT_SLOW_MO ?? '0');
export const playwrightDisableWebserver = process.env.PLAYWRIGHT_DISABLE_WEBSERVER;

process.env.PW_EXPERIMENTAL_SERVICE_WORKER_NETWORK_EVENTS = '1';

const config: PlaywrightTestConfig = {
  testDir: './src/ui/specs',
  testMatch: /.*\.e2e-spec\.ts/,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 4 : 0,
  reporter: 'html',
  use: {
    baseURL: playwriteBaseUrl,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    launchOptions: {
      slowMo: playwriteSlowMo,
    },
  },

  workers: process.env.CI ? 4 : Math.round(cpus().length * 0.75),

  projects: [
    {
      name: 'ui',
      use: { ...devices['Desktop Chrome'] },
      fullyParallel: true,
      workers: process.env.CI ? 3 : Math.max(1, Math.round(cpus().length * 0.75) - 1),
    },
  ],

  webServer: {
    command: 'pnpm --dir ../web exec vite dev --host 127.0.0.1 --port 2285',
    url: 'http://127.0.0.1:2285',
    stdout: 'pipe',
    stderr: 'pipe',
    reuseExistingServer: true,
  },
};
if (playwrightDisableWebserver) {
  delete config.webServer;
}
export default defineConfig(config);
