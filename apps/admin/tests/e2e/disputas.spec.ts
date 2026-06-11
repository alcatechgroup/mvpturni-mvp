import { test, expect, Page } from '@playwright/test';

/**
 * STORY-096 / ADR-020 / DDR-005 — E2E em browser real da fila de disputas do Backoffice:
 * fila derivada do estado `em_disputa` → caso (drawer) com trilha → resolver "pagar integral"
 * (comando da api via canal interno — IDR-032; nota OBRIGATÓRIA — DDR-005 Decisão 3).
 *
 * Pré-requisito: `make _e2e-seed` (TurnosSeeder cria o turno `em_disputa` determinístico do
 * "Estabelecimento Disputa 096 Seed", aberto há ~42 min → SLA estourado 🔴). O cenário (a)
 * CONSOME o turno (resolução o transita para `finalizado`); o seed o recria na próxima execução.
 * Roda contra localhost:8002 (ou BASE_URL).
 *
 * Caminhos mapeados (cada um é um cenário — disciplina E2E):
 * (a) feliz: fila lista o caso com SLA → abrir caso → trilha + justificativa → resolver com nota
 *     → toast de sucesso + caso sai da fila;
 * (b) exceção do usuário: confirmar SEM nota → erro de validação, caso não resolve;
 * (c) alternativo: abrir e fechar o caso (drawer) sem resolver — o caso continua na fila.
 */

const adminEmail = process.env.ADMIN_SEED_EMAIL ?? 'admin@turni.local';
const adminPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';
const estabelecimentoSeed = 'Estabelecimento Disputa 096 Seed';

async function loginAndOpenDisputas(page: Page) {
  await page.goto('/login');
  await page.locator('[data-testid="input-email"]').fill(adminEmail);
  await page.locator('[data-testid="input-password"]').fill(adminPassword);
  await page.locator('[data-testid="btn-submit-login"]').click();
  await expect(page).toHaveURL('/');
  // Caminho real do usuário: pela sidebar (DDR-005), não por URL direta.
  await page.locator('[data-testid="nav-disputas"]').click();
  await expect(page).toHaveURL(/\/disputas/);
  await expect(page.locator('[data-testid="screen-disputas"]')).toBeVisible();
}

test.describe('Backoffice — fila de disputas (STORY-096)', () => {
  test('(b) nota vazia não resolve: erro de validação visível, caso permanece', async ({ page }) => {
    await loginAndOpenDisputas(page);

    const linha = page.locator('tr', { hasText: estabelecimentoSeed });
    await expect(linha).toBeVisible();
    // SLA estourado (seed aberto há ~42 min) — indicador vermelho + texto, não só cor.
    await expect(linha.locator('[data-testid$="-sla"]')).toContainText('min');

    await linha.locator('[data-testid$="-ver"]').click();
    await expect(page.locator('[data-testid="disputas-caso"]')).toBeVisible();
    await page.locator('[data-testid="disputas-caso-resolver"]').click();
    await expect(page.locator('[data-testid="dialog-resolver"]')).toBeVisible();

    // Confirmar sem nota → erro (nota obrigatória — DDR-005 Decisão 3).
    await page.locator('[data-testid="dialog-resolver-confirm"]').click();
    await expect(page.locator('[data-testid="resolver-nota-erro"]'))
      .toHaveText('Descreva o motivo da decisão antes de confirmar.');

    // Voltar fecha o dialog sem resolver — o caso continua na fila.
    await page.locator('[data-testid="dialog-resolver-cancel"]').click();
    await expect(page.locator('[data-testid="dialog-resolver"]')).toHaveCount(0);
    await page.locator('[data-testid="disputas-caso-close"]').click();
    await expect(page.locator('tr', { hasText: estabelecimentoSeed })).toBeVisible();
  });

  test('(a) caso completo: trilha + justificativa, resolver com nota → toast + sai da fila', async ({ page }) => {
    await loginAndOpenDisputas(page);

    const linha = page.locator('tr', { hasText: estabelecimentoSeed });
    await expect(linha).toBeVisible();
    await expect(linha.getByText('R$ 230,00')).toBeVisible();
    // Banner de SLA estourado (o seed abre a disputa há ~42 min).
    await expect(page.locator('[data-testid="disputas-sla-banner"]')).toBeVisible();

    // Abrir o caso (drawer) — trilha + justificativa do contratante.
    await linha.locator('[data-testid$="-ver"]').click();
    const caso = page.locator('[data-testid="disputas-caso"]');
    await expect(caso).toBeVisible();
    await expect(page.locator('[data-testid="caso-justificativa"]'))
      .toContainText('não terminou a limpeza do salão');
    await expect(page.locator('[data-testid="caso-trilha"]')).toContainText('Disputa aberta');
    await expect(page.locator('[data-testid="caso-trilha"]')).toContainText('Check-in validado');

    // Resolver "pagar integral" com nota → comando da api (IDR-032) → toast + sai da fila.
    await page.locator('[data-testid="disputas-caso-resolver"]').click();
    await page.locator('[data-testid="resolver-nota-input"]')
      .fill('Justificativa do contratante procede; pagar integral ao profissional (E2E).');
    await page.locator('[data-testid="dialog-resolver-confirm"]').click();

    await expect(page.locator('[data-testid="disputas-toast"]'))
      .toContainText('Disputa resolvida — pagamento integral liberado.');
    await expect(page.locator('tr', { hasText: estabelecimentoSeed })).toHaveCount(0);
  });
});
