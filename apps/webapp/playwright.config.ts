import { defineConfig, devices } from '@playwright/test';

/**
 * E2E do WebApp Flutter (CA-10 de STORY-008) — roda contra app.homolog.turni.com.br após deploy.
 * Localmente: BASE_URL=http://localhost:8003 npm run e2e
 */
export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false,
    retries: 1,
    timeout: 60_000,
    reporter: [['list'], ['html', { open: 'never' }]],

    use: {
        baseURL: process.env.BASE_URL ?? 'https://app.homolog.turni.com.br',
        viewport: { width: 390, height: 844 },
        screenshot: 'only-on-failure',
        trace: 'on-first-retry',
    },

    projects: [
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
        },
    ],
});
