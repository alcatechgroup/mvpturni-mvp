import { defineConfig, devices } from '@playwright/test';

/**
 * E2E do Backoffice — gate LOCAL antes de criar tag rc.N (IDR-004 / quality-standards.md §2.2).
 * Pipeline de release NÃO roda Playwright; pós-deploy faz apenas smoke curl.
 *
 *   Default: http://localhost:8002 (docker-compose via `make setup`)
 *   Contra homolog (debug manual): BASE_URL=<cloud-run-url> npx playwright test
 */
export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false,
    retries: 1,
    timeout: 30_000,
    reporter: [['list'], ['html', { open: 'never' }]],

    use: {
        baseURL: process.env.BASE_URL ?? 'http://localhost:8002',
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
