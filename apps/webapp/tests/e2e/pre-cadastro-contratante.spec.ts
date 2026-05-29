import { test, expect, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';

/**
 * STORY-018 — CA-9 — E2E do pré-cadastro de contratante (Flutter Web).
 *
 * Caminho feliz: cadastrar → ver a tela de recebido → tentar logar com o e-mail
 * recém-cadastrado → ver a mensagem de "aguardando aprovação" (banner-pending do login,
 * agnóstico de papel). Cada execução usa um e-mail único (a API rejeita e-mail repetido —
 * CA-4), para ser idempotente.
 *
 * Como no login/profissional, o Flutter Web pinta em <canvas>; a árvore acessível só
 * existe após ativar "Enable accessibility". `gotoApp` faz isso.
 *
 * Default: http://localhost:8003 (IDR-004). Pré-requisito: API no ar + migrações.
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

  // Tipo de operação (dropdown exposto como button) — abre e escolhe uma opção estática.
  await page.getByRole('button', { name: /Tipo de operação/ }).click();
  await page.waitForTimeout(1200);
  await page.getByRole('menuitem', { name: 'Restaurante' }).click();
  await page.waitForTimeout(500);

  // Foto — image_picker_for_web abre um <input type=file>; capturamos o filechooser.
  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: /Adicionar foto/ }).click();
  const chooser = await chooserPromise;
  await chooser.setFiles(fotoPath);
  await page.waitForTimeout(500);

  // Senha + confirmação.
  await typeInto(page, 'Senha', 'SenhaForte10');
  await typeInto(page, 'Confirmar senha', 'SenhaForte10');

  // Aceite dos Termos (checkbox sem nome no semantics).
  await page.getByRole('checkbox').click();
}

test.describe('WebApp — pré-cadastro de contratante (CA-9)', () => {
  test('tela pública carrega sem auth', async ({ page }) => {
    await gotoApp(page, '/cadastro/contratante');
    await expect(page).toHaveURL(/\/cadastro\/contratante$/);
    await expect(page.getByText('Criar conta de estabelecimento')).toBeVisible();
  });

  test('cadastra, vê recebido e ao logar vê "aguardando aprovação"', async ({ page }) => {
    await gotoApp(page, '/cadastro/contratante');
    const email = `contratante.${Date.now()}@e2e.local`;
    await preencherCadastro(page, email);

    await page.getByRole('button', { name: 'Enviar cadastro' }).click();
    await page.waitForTimeout(4000);

    await expect(page.getByText('Cadastro recebido.')).toBeVisible({ timeout: 10000 });
    await expect(page.getByText('Voltar à home')).toBeVisible();

    // CA-8 / CA-9: tentar logar com o e-mail recém-cadastrado → conta em análise.
    await gotoApp(page, '/login');
    await typeInto(page, 'E-mail', email);
    await typeInto(page, 'Senha', 'SenhaForte10');
    await page.getByRole('button', { name: 'Entrar' }).click();
    await page.waitForTimeout(3000);

    await expect(page.getByText(/em análise/i)).toBeVisible({ timeout: 10000 });
  });
});
