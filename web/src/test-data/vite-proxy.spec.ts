import type { ProxyOptions } from 'vite';
import { proxy } from '../../vite-proxy';

describe('Vite backend proxy', () => {
  it('rewrites the websocket origin for the remote backend', () => {
    const apiProxy = proxy['/api'] as ProxyOptions;

    expect(apiProxy).toMatchObject({
      changeOrigin: true,
      rewriteWsOrigin: true,
      ws: true,
    });
  });
});
