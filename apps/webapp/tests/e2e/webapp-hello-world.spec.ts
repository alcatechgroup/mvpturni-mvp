import { test, expect } from '@playwright/test';

/**
 * CA-10: caminho feliz do hello world do WebApp Flutter.
 * O WebApp usa Flutter Web (CanvasKit) — o conteúdo renderizado é Canvas.
 * Os testes verificam via HTTP os endpoints que importam para o EPIC-000:
 *   - raiz carrega sem erro (200, título correto)
 *   - /health retorna 200 com payload ADR-008
 *   - /version.json retorna versão coerente com a tag deployada
 */

test.describe('WebApp — hello world (CA-10)', () => {
    test('raiz retorna 200 com título Turni', async ({ page }) => {
        const response = await page.goto('/');

        expect(response?.status()).toBe(200);
        await expect(page).toHaveTitle(/Turni/);
    });

    test('/health retorna 200 com payload ADR-008 (service=webapp)', async ({ page }) => {
        const response = await page.request.get('/health');

        expect(response.status()).toBe(200);

        const body = await response.json();
        expect(body.status).toBe('ok');
        expect(body.service).toBe('webapp');
        expect(body.version).toBeTruthy();
        expect(body.timestamp).toBeTruthy();
    });

    test('/version.json expõe a tag deployada', async ({ page }) => {
        const response = await page.request.get('/version.json');

        expect(response.status()).toBe(200);

        const body = await response.json();
        expect(body.version).toBeTruthy();
        expect(typeof body.version).toBe('string');
        expect(body.version.length).toBeGreaterThan(0);
    });

    test('página carrega sem erros de console críticos', async ({ page }) => {
        const errors: string[] = [];
        page.on('pageerror', (err) => errors.push(err.message));

        await page.goto('/');
        // Aguarda Flutter inicializar (CanvasKit pode demorar em cold start)
        await page.waitForTimeout(5_000);

        const criticalErrors = errors.filter(
            (e) => !e.includes('font') && !e.includes('404')
        );
        expect(criticalErrors).toHaveLength(0);
    });
});
