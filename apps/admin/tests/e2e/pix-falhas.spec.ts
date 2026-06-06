import { test, expect, Page } from '@playwright/test';

/**
 * STORY-065 — CA-5/CA-8 — E2E em browser real da fila de falhas, generalizada pela
 * STORY-066 (CA-4) para "Falhas de pagamento": casos de LIBERAÇÃO de pré-autorização
 * convivem com os de Pix (badge por tipo; liberação sem chave Pix).
 *
 * Pré-requisito: `make _e2e-seed` (PixFalhaSeeder reabre os casos determinísticos
 * "Carlos Pix Falho (seed)" [pix] e "Pedro Liberação Falha (seed)" [liberacao]).
 * Roda contra localhost:8002 (ou BASE_URL). Com 2+ casos na fila, toda ação por
 * linha ancora na LINHA do caso (lição da 066: `.first()` resolvia o caso errado).
 *
 * Caminhos mapeados (cada um vira cenário — disciplina E2E):
 * (a) feliz: fila lista os 2 casos com badge/valor/chave/razão por tipo; copiar
 *     chave; resolver o caso Pix com nota → some de Pendentes, vai a Resolvidos;
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

    // STORY-066 (CA-4) — caso de LIBERAÇÃO na mesma fila: badge próprio, sem chave
    // Pix (célula "—"), valor = total reservado, razão do gateway.
    const linhaLiberacao = page.locator('tr', { hasText: 'Pedro Liberação Falha (seed)' });
    await expect(linhaLiberacao.getByText('Liberação falhou — tratamento manual')).toBeVisible();
    await expect(linhaLiberacao.locator('[data-testid$="-chave"]')).toHaveText('—');
    await expect(linhaLiberacao.getByText('R$ 230,00')).toBeVisible();
    await expect(linhaLiberacao.getByText(/release_failed/)).toBeVisible();

    // Copiar chave Pix (parte do trabalho real do admin) — só o caso Pix a tem.
    const linhaPix = page.locator('tr', { hasText: 'Carlos Pix Falho (seed)' });
    await linhaPix.locator('[data-testid$="-copiar"]').click();
    await expect(page.getByText('Copiada')).toBeVisible();
    expect(await page.evaluate(() => navigator.clipboard.readText()))
      .toBe('carlos.seed@pix.turni.local');

    // Resolver o caso PIX com nota (CA-8) → toast + sai de Pendentes. Ancorado na
    // linha: com a fila generalizada (066) há 2+ casos e .first() seria o errado.
    await linhaPix.locator('[data-testid$="-resolver"]').click();
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
