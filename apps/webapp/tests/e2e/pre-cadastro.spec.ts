import { test, expect, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';

/**
 * STORY-017 / STORY-043 — pré-cadastro de profissional (Flutter Web).
 *
 * As validações/carga/navegação MIGRARAM para integration_test same-origin
 * (`integration_test/cadastro/pre_cadastro_profissional_test.dart` — STORY-043 CA-6).
 *
 * Aqui resta SÓ o happy-path com upload de foto, mantido `test.fixme`: o file picker do
 * browser (image_picker_for_web) é flaky no padrão de semantics (IDR-006 §b) e NÃO migra
 * para integration_test (IDR-009: Web → Playwright, nativo → Patrol). Cobertura nativa do
 * picker fica para STORY-039 (Patrol). Nenhum target do gate roda este spec.
 */

const fotoPath = fileURLToPath(new URL('./fixtures/foto.png', import.meta.url));

async function gotoApp(page: Page, route: string) {
  await page.goto(route);
  await page.waitForTimeout(2000);
  for (let i = 0; i < 12; i++) {
    await page.evaluate(() => {
      const el = document.querySelector('flt-semantics-placeholder') as HTMLElement | null;
      el?.click();
    });
    if ((await page.locator('flt-semantics').count()) > 0) break;
    await page.waitForTimeout(500);
  }
}

async function typeInto(page: Page, label: string, value: string) {
  const field = page.getByRole('textbox', { name: label, exact: true });
  await field.focus();
  await page.waitForTimeout(80);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(value, { delay: 20 });
}

async function preencherCadastro(page: Page, email: string, tipo: 'PF' | 'MEI') {
  await typeInto(page, 'Nome completo', 'Diego Profissional E2E');
  await typeInto(page, 'E-mail', email);
  await typeInto(page, 'Telefone', '(11) 91234-5678');
  await typeInto(page, 'Cidade', 'São Paulo');
  await typeInto(page, 'Bairro', 'Pinheiros');

  await page.getByRole('button', { name: /Função pretendida/ }).click();
  await page.waitForTimeout(1200);
  await page.getByRole('menuitem', { name: 'Bartender' }).click();
  await page.waitForTimeout(500);

  await page.getByRole('button', { name: tipo, exact: true }).click();

  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: /Adicionar foto/ }).click();
  const chooser = await chooserPromise;
  await chooser.setFiles(fotoPath);
  await page.waitForTimeout(500);

  await typeInto(page, 'Senha', 'SenhaForte10');
  await typeInto(page, 'Confirmar senha', 'SenhaForte10');

  await page.getByRole('checkbox').click();
}

test.describe('WebApp — pré-cadastro de profissional (happy-path c/ foto)', () => {
  // DESATIVADO (IDR-009 / STORY-043 CA-6): upload de foto via file picker do browser não
  // migra para integration_test; recolocado com a ferramenta certa em STORY-039 (Patrol).
  for (const tipo of ['PF', 'MEI'] as const) {
    test.fixme(`envia cadastro ${tipo} e vê a tela de recebido`, async ({ page }) => {
      await gotoApp(page, '/cadastro/profissional');
      const email = `prof.${tipo.toLowerCase()}.${Date.now()}@e2e.local`;
      await preencherCadastro(page, email, tipo);

      await page.getByRole('button', { name: 'Enviar cadastro' }).click();
      await page.waitForTimeout(4000);

      await expect(page.getByText('Cadastro recebido.')).toBeVisible({ timeout: 10000 });
      await expect(page.getByText('Voltar à home')).toBeVisible();
    });
  }
});
