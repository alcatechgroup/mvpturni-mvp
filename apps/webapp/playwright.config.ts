import { defineConfig, devices } from '@playwright/test';

/**
 * E2E do WebApp Flutter — gate LOCAL antes de criar tag rc.N (IDR-004 / quality-standards.md §2.2).
 * Pipeline de release NÃO roda Playwright; pós-deploy faz apenas smoke curl.
 *
 *   Default: http://localhost:8003 (docker-compose via `make setup`)
 *   Contra homolog (debug manual): BASE_URL=https://app.homolog.turni.com.br npx playwright test
 */
export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false,
    // 1 worker: Flutter Web/CanvasKit é pesado no boot; instâncias paralelas
    // contendem CPU e deixam a ativação de semantics flaky. Serial é determinístico.
    workers: 1,
    retries: 1,
    timeout: 60_000,
    reporter: [['list'], ['html', { open: 'never' }]],

    use: {
        baseURL: process.env.BASE_URL ?? 'http://localhost:8003',
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
