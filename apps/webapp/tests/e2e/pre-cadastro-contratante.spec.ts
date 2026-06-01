import { test, expect, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';

/**
 * STORY-018 / STORY-043 — pré-cadastro de contratante (Flutter Web).
 *
 * As validações/carga/navegação MIGRARAM para integration_test same-origin
 * (`integration_test/cadastro/pre_cadastro_contratante_test.dart` — STORY-043 CA-6).
 *
 * Aqui resta SÓ o happy-path com upload de foto, mantido `test.fixme` (IDR-009: file picker
 * do browser não migra para integration_test; cobertura nativa em STORY-039 com Patrol).
 * Nenhum target do gate roda este spec.
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

async function preencherCadastro(page: Page, email: string) {
  await typeInto(page, 'Nome do responsável', 'Maria Souza E2E');
  await typeInto(page, 'E-mail', email);
  await typeInto(page, 'Telefone', '(11) 91234-5678');
  await typeInto(page, 'Nome do estabelecimento', 'Bar do Porto E2E');
  await typeInto(page, 'Cidade', 'São Paulo');

  await page.getByRole('button', { name: /Tipo de operação/ }).click();
  await page.waitForTimeout(1200);
  await page.getByRole('menuitem', { name: 'Restaurante' }).click();
  await page.waitForTimeout(500);

  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: /Adicionar foto/ }).click();
  const chooser = await chooserPromise;
  await chooser.setFiles(fotoPath);
  await page.waitForTimeout(500);

  await typeInto(page, 'Senha', 'SenhaForte10');
  await typeInto(page, 'Confirmar senha', 'SenhaForte10');

  await page.getByRole('checkbox').click();
}

test.describe('WebApp — pré-cadastro de contratante (happy-path c/ foto)', () => {
  // DESATIVADO (IDR-009 / STORY-043 CA-6): upload de foto via file picker do browser →
  // STORY-039 (Patrol). As validações estão cobertas em integration_test.
  test.fixme('cadastra, vê recebido e ao logar vê "aguardando aprovação"', async ({ page }) => {
    await gotoApp(page, '/cadastro/contratante');
    const email = `contratante.${Date.now()}@e2e.local`;
    await preencherCadastro(page, email);

    await page.getByRole('button', { name: 'Enviar cadastro' }).click();
    await page.waitForTimeout(4000);

    await expect(page.getByText('Cadastro recebido.')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('Voltar à home')).toBeVisible();

    await gotoApp(page, '/login');
    await typeInto(page, 'E-mail', email);
    await typeInto(page, 'Senha', 'SenhaForte10');
    await page.getByRole('button', { name: 'Entrar' }).click();
    await page.waitForTimeout(3000);

    await expect(page.getByText(/em análise/i)).toBeVisible({ timeout: 10000 });
  });
});
