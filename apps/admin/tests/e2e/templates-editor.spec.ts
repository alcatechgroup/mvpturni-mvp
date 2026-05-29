import { test, expect, Page } from '@playwright/test';

/**
 * STORY-020 — CA-15 — E2E em browser real do editor de templates contratuais.
 *
 * Pré-requisito: `make _e2e-seed` (db:seed cria o admin + catálogo de templates com a v1 ativa).
 * Roda contra localhost:8002 (ou BASE_URL).
 *
 * (a) admin abre o catálogo e vê os 2 templates do MVP;
 * (b) cria nova versão do template PF (editor + preview) e salva → nova versão histórica;
 * (c) ativa a nova versão → catálogo passa a apontá-la como ativa; a v1 continua existindo
 *     como histórica com conteúdo inalterado (núcleo de imutabilidade de PDR-012 — o aceite
 *     eletrônico apontando para a v1 é validado em STORY-023/024, que cria essa tabela).
 *
 * Idempotente entre execuções: a versão criada é descoberta dinamicamente (não fixa em "v2").
 */

const adminEmail = process.env.ADMIN_SEED_EMAIL ?? 'admin@turni.local';
const adminPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';

async function loginAndOpenTemplates(page: Page) {
  await page.goto('/login');
  await page.locator('[data-testid="input-email"]').fill(adminEmail);
  await page.locator('[data-testid="input-password"]').fill(adminPassword);
  await page.locator('[data-testid="btn-submit-login"]').click();
  await expect(page).toHaveURL('/');
  // Caminho real do usuário: navega pelo menu principal (CA-1).
  await page.locator('[data-testid="nav-templates"]').click();
  await expect(page).toHaveURL(/\/templates/);
  await expect(page.locator('[data-testid="templates-catalogo"]')).toBeVisible();
}

test.describe('Backoffice — editor de templates (CA-15)', () => {
  test('(a) catálogo lista os 2 templates do MVP', async ({ page }) => {
    await loginAndOpenTemplates(page);

    await expect(page.locator('[data-testid="templates-catalogo-item-pf_autonomo_eventual"]')).toBeVisible();
    await expect(page.locator('[data-testid="templates-catalogo-item-mei_pj_b2b"]')).toBeVisible();
    await expect(page.locator('[data-testid="templates-catalogo-item-pf_autonomo_eventual-ativa"]')).toContainText('ativa');
  });

  test('(b+c) cria nova versão do PF, salva e ativa → catálogo aponta a nova ativa', async ({ page }) => {
    await loginAndOpenTemplates(page);

    // Abre o detalhe do template PF.
    await page.locator('[data-testid="templates-catalogo-item-pf_autonomo_eventual-abrir"]').click();
    await expect(page.locator('[data-testid="template-detalhe"]')).toBeVisible();
    // A versão ativa renderiza com placeholder visível como chip.
    await expect(page.locator('[data-testid="template-detalhe-ativa"]')).toContainText('⟦profissional.nome⟧');

    // Abre o editor de nova versão (pré-carregado com a versão ativa).
    await page.locator('[data-testid="template-detalhe-criar-versao"]').click();
    await expect(page.locator('[data-testid="template-editor"]')).toBeVisible();
    const textarea = page.locator('[data-testid="template-editor-textarea"]');
    await expect(textarea).not.toBeEmpty();

    // Edita: acrescenta um parágrafo válido ao fim e confere o preview ao vivo.
    const marca = `Cláusula de teste E2E ${Date.now()}`;
    await textarea.focus();
    await textarea.press('End');
    await page.keyboard.type(`\n\n${marca}`);
    await expect(page.locator('[data-testid="template-editor-preview"]')).toContainText(marca);

    // Salva → volta ao detalhe com toast e nova versão no histórico.
    await page.locator('[data-testid="template-editor-salvar"]').click();
    await expect(page).toHaveURL(/\/templates\/pf_autonomo_eventual$/);
    await expect(page.locator('[data-testid="templates-toast"]')).toContainText('criada como rascunho');

    // Descobre o maior número de versão (a recém-criada) no histórico.
    const statusChips = page.locator('[data-testid^="template-versao-"][data-testid$="-status"]');
    await expect(statusChips.first()).toBeVisible();
    const novaVersao = await page.locator('[data-testid="template-detalhe-historico"]')
      .locator('[data-testid^="template-versao-"][data-testid$="-status"]')
      .first()
      .getAttribute('data-testid');
    const numero = novaVersao!.replace('template-versao-', '').replace('-status', '');

    // A nova versão está como histórica (rascunho, ainda não ativa).
    await expect(page.locator(`[data-testid="template-versao-${numero}-status"]`)).toContainText('histórica');

    // Ativa a nova versão → confirmação dupla explica que aceites passados não mudam.
    await page.locator(`[data-testid="template-versao-${numero}-ativar"]`).click();
    const dialog = page.getByRole('alertdialog');
    await expect(dialog).toContainText('não mudam');
    await page.locator('[data-testid="dialog-ativar-confirm"]').click();
    await expect(page.locator('[data-testid="templates-toast"]')).toContainText('ativada');

    // Agora a nova versão consta como ativa e a v1 segue existindo como histórica.
    await expect(page.locator(`[data-testid="template-versao-${numero}-status"]`)).toContainText('ativa');
    await expect(page.locator('[data-testid="template-versao-1-status"]')).toContainText('histórica');

    // Catálogo reflete a nova versão ativa.
    await page.locator('[data-testid="template-detalhe-voltar"]').click();
    await expect(page.locator('[data-testid="templates-catalogo-item-pf_autonomo_eventual-ativa"]'))
      .toContainText(`v${numero} · ativa`);
  });

  test('(d) salvar com placeholder fora da lista é bloqueado com mensagem acionável (CA-5)', async ({ page }) => {
    await loginAndOpenTemplates(page);
    await page.locator('[data-testid="templates-catalogo-item-mei_pj_b2b-abrir"]').click();
    await page.locator('[data-testid="template-detalhe-criar-versao"]').click();

    const textarea = page.locator('[data-testid="template-editor-textarea"]');
    await textarea.focus();
    await textarea.press('End');
    await page.keyboard.type('\n\nErro: {{contratante.razao_zocial}}');

    await page.locator('[data-testid="template-editor-salvar"]').click();

    await expect(page.locator('[data-testid="template-editor-erro"]')).toContainText('contratante.razao_zocial');
    // Continua no editor (não redirecionou) — nada foi salvo.
    await expect(page.locator('[data-testid="template-editor"]')).toBeVisible();
  });
});
