import { test, expect, Page } from '@playwright/test';

/**
 * STORY-065 — CA-5/CA-8 — E2E em browser real da fila "Pix com falha".
 *
 * Pré-requisito: `make _e2e-seed` (PixFalhaSeeder reabre o caso determinístico
 * "Carlos Pix Falho (seed)"). Roda contra localhost:8002 (ou BASE_URL).
 *
 * Caminhos mapeados (cada um vira cenário — disciplina E2E):
 * (a) feliz: fila lista o caso com badge/valor/chave/razão; copiar chave; resolver
 *     com nota → caso some de Pendentes e aparece em Resolvidos com nota+autor;
 * (b) exceção do usuário: confirmar SEM nota → erro de validação, caso não resolve;
 * (c) alternativo: aba Resolvidos ↔ Pendentes (estado vazio positivo quando zera).
 */

const adminEmail = process.env.ADMIN_SEED_EMAIL ?? 'admin@turni.local';
const adminPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';

async function loginAndOpenPixFalhas(page: Page) {
  await page.goto('/login');
  await page.locator('[data-testid="input-email"]').fill(adminEmail);
  await page.locator('[data-testid="input-password"]').fill(adminPassword);
  await page.locator('[data-testid="btn-submit-login"]').click();
  await expect(page).toHaveURL('/');
  // Caminho real do usuário: pela sidebar (SCREEN-065 §B.2), não por URL direta.
  await page.locator('[data-testid="nav-pix-falhas"]').click();
  await expect(page).toHaveURL(/\/pix-falhas/);
  await expect(page.locator('[data-testid="screen-pix-falhas"]')).toBeVisible();
}

test.describe('Backoffice — fila "Pix com falha" (STORY-065)', () => {
  test('(b) nota vazia não resolve: erro de validação visível', async ({ page }) => {
    await loginAndOpenPixFalhas(page);

    const caso = page.getByText('Carlos Pix Falho (seed)');
    await expect(caso).toBeVisible();

    await page.locator('[data-testid$="-resolver"]').first().click();
    await expect(page.locator('[data-testid="pixfalhas-dialog"]')).toBeVisible();

    await page.locator('[data-testid="pixfalhas-dialog-confirmar"]').click();
    await expect(page.locator('[data-testid="pixfalhas-dialog-nota-erro"]'))
      .toHaveText('Descreva o que foi feito antes de confirmar.');

    // Cancelar fecha sem resolver — o caso continua na fila.
    await page.locator('[data-testid="pixfalhas-dialog-cancelar"]').click();
    await expect(page.locator('[data-testid="pixfalhas-dialog"]')).toHaveCount(0);
    await expect(caso).toBeVisible();
  });

  test('(a) caso completo: badge CA-5, copiar chave, resolver com nota → Resolvidos', async ({ page, context }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    await loginAndOpenPixFalhas(page);

    // CA-5 — badge vermelho + microcopy + valor + chave + razão do gateway.
    await expect(page.getByText('Pix falhou — tratamento manual').first()).toBeVisible();
    await expect(page.getByText('Carlos Pix Falho (seed)')).toBeVisible();
    await expect(page.getByText('R$ 200,00').first()).toBeVisible();
    await expect(page.getByText('carlos.seed@pix.turni.local')).toBeVisible();
    await expect(page.getByText(/invalid_pix_key/).first()).toBeVisible();

    // Copiar chave Pix (parte do trabalho real do admin).
    await page.locator('[data-testid$="-copiar"]').first().click();
    await expect(page.getByText('Copiada')).toBeVisible();
    expect(await page.evaluate(() => navigator.clipboard.readText()))
      .toBe('carlos.seed@pix.turni.local');

    // Resolver com nota (CA-8) → toast + sai de Pendentes.
    await page.locator('[data-testid$="-resolver"]').first().click();
    await page.locator('[data-testid="pixfalhas-dialog-nota"]')
      .fill('Pix manual feito pela conta Turni (E2E)');
    await page.locator('[data-testid="pixfalhas-dialog-confirmar"]').click();

    await expect(page.locator('[data-testid="pixfalhas-toast"]'))
      .toContainText('Caso resolvido. Registrado no histórico de auditoria.');
    await expect(page.getByText('Carlos Pix Falho (seed)')).toHaveCount(0);

    // (c) Aba Resolvidos: caso com nota + autor; badge neutro.
    await page.locator('[data-testid="pixfalhas-tab-resolvidos"]').click();
    await expect(page.getByText('Carlos Pix Falho (seed)')).toBeVisible();
    await expect(page.getByText('Resolvido manualmente').first()).toBeVisible();
    await expect(page.getByText('Pix manual feito pela conta Turni (E2E)')).toBeVisible();

    // Volta a Pendentes — se a fila zerou, estado vazio POSITIVO (SCREEN-065 §B.5).
    await page.locator('[data-testid="pixfalhas-tab-pendentes"]').click();
    const lista = page.locator('[data-testid="pixfalhas-list"]');
    const vazio = page.locator('[data-testid="pixfalhas-empty"]');
    await expect(lista.or(vazio).first()).toBeVisible();
  });
});
