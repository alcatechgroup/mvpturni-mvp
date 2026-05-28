import { test, expect } from '@playwright/test';

/**
 * Smoke do Backoffice — comportamento público pós-STORY-016.
 *
 * STORY-008 servia uma home "hello world" pública com badge de versão e link
 * /health. STORY-016 trancou a home atrás do guard de admin: `/` agora
 * redireciona para `/login` quando não autenticado. A versão deixou de ser um
 * badge visível na home — passou a viver no payload de `/health` (ADR-008) e em
 * `/version.json` (verificado pelo smoke do pipeline). Estes testes refletem a
 * realidade atual; o caminho autenticado é coberto em rbac-login.spec.ts.
 *
 * Default: http://localhost:8002 (IDR-004). Homolog: BASE_URL=<cloud-run-url>.
 */

test.describe('Backoffice — smoke público (pós-STORY-016)', () => {
    test('`/` sem autenticação redireciona para /login (guard AdminOnly)', async ({ page }) => {
        await page.goto('/');
        await expect(page).toHaveURL(/\/login$/);
        // Tela de login do Backoffice renderiza
        await expect(page.locator('[data-testid="screen-login-backoffice"]')).toBeVisible();
    });

    test('/health retorna 200 com payload ADR-008 (service=backoffice, version)', async ({ page }) => {
        const response = await page.request.get('/health');

        expect(response.status()).toBe(200);

        const body = await response.json();
        expect(body.status).toBe('ok');
        expect(body.service).toBe('backoffice');
        expect(body.version).toBeTruthy();
        expect(body.timestamp).toBeTruthy();
    });

    test('X-Request-Id está presente no response (CA-7)', async ({ page }) => {
        const response = await page.request.get('/health');

        expect(response.status()).toBe(200);
        // Cloud Run injeta X-Cloud-Trace-Context; o middleware propaga como X-Request-Id
        const requestId = response.headers()['x-request-id'];
        expect(requestId).toBeTruthy();
        expect(requestId.length).toBeGreaterThan(0);
    });
});
