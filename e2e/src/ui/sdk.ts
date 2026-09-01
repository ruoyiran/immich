import { setBaseUrl } from '@immich/sdk';
import { playwriteBaseUrl } from '../../playwright.config';

export const initializeSdk = () => setBaseUrl(`${playwriteBaseUrl}/api`);
