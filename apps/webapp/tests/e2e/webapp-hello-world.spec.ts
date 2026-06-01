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

    // FOLLOW-UP (IDR-004 / 2026-05-28): `/health` JSON do WebApp só existe no build
    // de release (o job build-webapp gera health.json em web/). No dev local servido
    // por docker-compose, `/health` cai no fallback SPA e retorna o shell HTML, então
    // este cenário é homolog-only. Reabilitar junto da estratégia de E2E do WebApp.
    test.fixme('/health retorna 200 com payload ADR-008 (service=webapp)', async ({ page }) => {
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

// ──────────────────────────────────────────────────────────────
// STORY-038 CA-12 — Deep link por path (proteção da IDR-006 §a).
// A interação com a UI (campos, RBAC, funnel) migrou para integration_test (IDR-010);
// aqui fica só o smoke HTTP do deep link: abrir /login direto na URL do browser deve
// carregar a rota /login e NÃO cair no root/WelcomeScreen. Sem usePathUrlStrategy()
// (hash strategy), o boot caía em initialLocation '/' — este cenário trava essa regressão.
// ──────────────────────────────────────────────────────────────
test.describe('WebApp — deep link path strategy (CA-12)', () => {
    test('deep link /login direto na URL carrega e permanece em /login', async ({ page }) => {
        const response = await page.goto('/login');

        // O servidor faz fallback SPA → 200 com index.html; o go_router resolve /login.
        expect(response?.status()).toBe(200);

        // Espera o boot do Flutter; com path strategy a URL permanece /login (path real),
        // sem virar hash (/#/...) nem redirecionar para o root.
        await page.waitForTimeout(3_000);
        await expect(page).toHaveURL(/\/login$/);
        expect(new URL(page.url()).hash).toBe('');
    });
});
