import { defineConfig, devices } from '@playwright/test';

/**
 * E2E do Backoffice (CA-10) — roda contra admin.homolog.turni.com.br após deploy.
 * Localmente: BASE_URL=http://localhost:8002 npm run e2e
 */
export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false,
    retries: 1,
    timeout: 30_000,
    reporter: [['list'], ['html', { open: 'never' }]],

    use: {
        baseURL: process.env.BASE_URL ?? 'https://admin.homolog.turni.com.br',
        // Desktop-only: Backoffice é desktop-first (PDR-003)
        viewport: { width: 1280, height: 800 },
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
