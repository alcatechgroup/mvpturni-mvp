import { test, expect } from '@playwright/test';

/**
 * CA-10: caminho feliz do hello world do Backoffice.
 * Roda contra admin.homolog.turni.com.br (ou BASE_URL local).
 */

test.describe('Backoffice — hello world (CA-10)', () => {
    test('página inicial carrega e exibe identificador do Backoffice', async ({ page }) => {
        await page.goto('/');

        // CA-1: identificador inequívoco na página
        await expect(page.locator('h1')).toContainText('Turni — Backoffice (Admin)');
        await expect(page).toHaveTitle(/Backoffice/);
    });

    test('versão está visível na página inicial (CA-1)', async ({ page }) => {
        await page.goto('/');

        const versionBadge = page.getByTestId('app-version');
        await expect(versionBadge).toBeVisible();

        const versionText = await versionBadge.textContent();
        expect(versionText?.trim().length).toBeGreaterThan(0);
    });

    test('link /health está presente e clicável (CA-1)', async ({ page }) => {
        await page.goto('/');

        const healthLink = page.getByTestId('health-link');
        await expect(healthLink).toBeVisible();
        await expect(healthLink).toHaveAttribute('href', '/health');
    });

    test('clicar no link /health retorna 200 com service=backoffice (CA-4, CA-10)', async ({ page }) => {
        await page.goto('/');

        // Navega para /health via clique no link
        await page.getByTestId('health-link').click();
        await expect(page).toHaveURL(/\/health/);

        const body = await page.locator('body').textContent();
        const json = JSON.parse(body ?? '{}');

        expect(json.status).toBe('ok');
        expect(json.service).toBe('backoffice');
        expect(json.version).toBeTruthy();
        expect(json.timestamp).toBeTruthy();
    });

    test('/health retorna 200 diretamente (CA-4)', async ({ page }) => {
        const response = await page.request.get('/health');

        expect(response.status()).toBe(200);

        const body = await response.json();
        expect(body.status).toBe('ok');
        expect(body.service).toBe('backoffice');
    });

    test('X-Request-Id está presente no response de / (CA-7)', async ({ page }) => {
        const response = await page.request.get('/');

        expect(response.status()).toBe(200);
        // Cloud Run injeta X-Cloud-Trace-Context; o middleware propaga como X-Request-Id
        const requestId = response.headers()['x-request-id'];
        expect(requestId).toBeTruthy();
        expect(requestId.length).toBeGreaterThan(0);
    });
});
