import { test, expect, Page } from '@playwright/test';

/**
 * STORY-019 — CA-13 — E2E em browser real da fila de aprovação.
 *
 * Pré-requisito: `make _e2e-seed` (db:seed cria admin + cadastros pendentes da
 * FilaAprovacaoPendentesSeeder). Roda contra localhost:8002 (ou BASE_URL).
 *
 * (a) lista pendentes e filtra por profissional MEI
 * (b) aprova um profissional → item sai da fila + e-mail despachado (toast)
 * (c) aprova o mesmo cadastro em 2 abas → 2ª tentativa erra com mensagem clara
 * (d) remove um cadastro com confirmação dupla
 */

const adminEmail = process.env.ADMIN_SEED_EMAIL ?? 'admin@turni.local';
const adminPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';

async function loginAndOpenQueue(page: Page) {
  await page.goto('/login');
  await page.locator('[data-testid="input-email"]').fill(adminEmail);
  await page.locator('[data-testid="input-password"]').fill(adminPassword);
  await page.locator('[data-testid="btn-submit-login"]').click();
  await expect(page).toHaveURL('/');
  // Caminho real do usuário: navega pelo MENU principal (CA-1), não por URL direta.
  await page.locator('[data-testid="nav-aprovacoes"]').click();
  await expect(page).toHaveURL(/\/aprovacoes/);
  await expect(page.locator('[data-testid="screen-aprovacoes"]')).toBeVisible();
}

test.describe('Backoffice — fila de aprovação (CA-13)', () => {
  test('(a) lista pendentes e filtra por profissional MEI', async ({ page }) => {
    await loginAndOpenQueue(page);

    // Lista tem itens; contador agregado visível.
    await expect(page.locator('[data-testid="aprovacoes-list"]')).toBeVisible();
    await expect(page.locator('[data-testid="aprovacoes-count-pendentes"]')).toBeVisible();
    await expect(page.getByText('Carlos Henrique Silva')).toBeVisible(); // MEI
    await expect(page.getByText('Pizzaria Mooca Ltda')).toBeVisible(); // contratante

    // Filtra por Profissional → MEI.
    await page.locator('[data-testid="aprovacoes-filter-papel-profissional"]').click();
    await page.locator('[data-testid="aprovacoes-filter-tipo-mei"]').click();

    await expect(page.getByText('Carlos Henrique Silva')).toBeVisible();
    await expect(page.getByText('Pizzaria Mooca Ltda')).toHaveCount(0); // contratante sumiu
    await expect(page.getByText('Diego Reis')).toHaveCount(0); // PF sumiu
  });

  test('(b) aprova um profissional → item sai da fila e e-mail é despachado', async ({ page }) => {
    await loginAndOpenQueue(page);

    // Abre detalhe do PF e aprova.
    await page.locator('[data-testid="aprovacoes-filter-papel-profissional"]').click();
    await page.getByText('Diego Reis').click({ trial: false }).catch(() => {});
    // CTA "Ver detalhes" da linha do Diego.
    const linha = page.locator('tr', { hasText: 'Diego Reis' });
    await linha.getByRole('button', { name: 'Ver detalhes' }).click();
    await expect(page.locator('[data-testid="aprovacoes-detail"]')).toBeVisible();

    await page.locator('[data-testid="aprovacoes-detail-aprovar"]').click();
    await page.locator('[data-testid="dialog-aprovar-confirm"]').click();

    // Toast confirma aprovação + e-mail; item sai da fila.
    await expect(page.locator('[data-testid="aprovacoes-toast"]')).toContainText('E-mail enviado');
    await expect(page.getByText('Diego Reis')).toHaveCount(0);
  });

  test('(c) aprovar o mesmo cadastro em 2 abas — 2ª erra com mensagem clara', async ({ browser }) => {
    const ctxA = await browser.newContext();
    const ctxB = await browser.newContext();
    const a = await ctxA.newPage();
    const b = await ctxB.newPage();
    await loginAndOpenQueue(a);
    await loginAndOpenQueue(b);

    const alvo = 'Ana Beatriz Eventos ME'; // PJ pendente
    for (const p of [a, b]) {
      const linha = p.locator('tr', { hasText: alvo });
      await linha.getByRole('button', { name: 'Ver detalhes' }).click();
      await expect(p.locator('[data-testid="aprovacoes-detail"]')).toBeVisible();
    }

    // Aba A aprova primeiro.
    await a.locator('[data-testid="aprovacoes-detail-aprovar"]').click();
    await a.locator('[data-testid="dialog-aprovar-confirm"]').click();
    await expect(a.locator('[data-testid="aprovacoes-toast"]')).toContainText('E-mail enviado');

    // Aba B tenta aprovar o mesmo → erro claro.
    await b.locator('[data-testid="aprovacoes-detail-aprovar"]').click();
    await b.locator('[data-testid="dialog-aprovar-confirm"]').click();
    await expect(b.locator('[data-testid="aprovacoes-toast"]')).toContainText('já foi processado por outro admin');

    await ctxA.close();
    await ctxB.close();
  });

  test('(d) remove um cadastro com confirmação dupla', async ({ page }) => {
    await loginAndOpenQueue(page);

    const alvo = 'Carlos Henrique Silva'; // MEI pendente
    const linha = page.locator('tr', { hasText: alvo });
    await linha.getByRole('button', { name: 'Ver detalhes' }).click();
    await expect(page.locator('[data-testid="aprovacoes-detail"]')).toBeVisible();

    // 1º clique: abre o diálogo de confirmação.
    await page.locator('[data-testid="aprovacoes-detail-remover"]').click();
    await expect(page.locator('[data-testid="dialog-remover-confirm"]')).toBeVisible();
    // 2º clique: confirma a remoção.
    await page.locator('[data-testid="dialog-remover-confirm"]').click();

    await expect(page.locator('[data-testid="aprovacoes-toast"]')).toContainText('Cadastro removido');
    await expect(page.getByText(alvo)).toHaveCount(0);
  });
});
