import type { ProxyOptions } from 'vite';

const upstream = {
  target: process.env.IMMICH_SERVER_URL || 'http://127.0.0.1:8080/',
  secure: true,
  changeOrigin: true,
  rewriteWsOrigin: true,
  logLevel: 'info',
  ws: true,
};

export const proxy: Record<string, string | ProxyOptions> = {
  '/api': upstream,
  '/.well-known/immich': upstream,
  '/custom.css': upstream,
};
