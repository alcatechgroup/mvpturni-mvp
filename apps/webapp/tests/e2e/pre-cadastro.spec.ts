import { test, expect, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';

/**
 * STORY-017 — CA-9 — E2E do pré-cadastro de profissional (Flutter Web).
 *
 * Cobre PF + MEI (PJ é o mesmo fluxo de MEI no formulário). Cada execução usa um
 * e-mail único (a API rejeita e-mail repetido — CA-4), para ser idempotente.
 *
 * Como no login (rbac-login.spec.ts), o Flutter Web pinta em <canvas>; a árvore
 * acessível só existe após ativar "Enable accessibility". `gotoApp` faz isso.
 *
 * Default: http://localhost:8003 (IDR-004). Pré-requisito: API no ar + migrações/seed
 * (funções vêm do FuncaoSeeder).
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
  // Flutter Web: o clique precisa focar o <input> de semantics ANTES de digitar,
  // senão as teclas vão para o campo anteriormente focado (poluindo o e-mail).
  // Garantimos foco (toBeFocused) e limpamos o campo antes de digitar.
  const field = page.getByRole('textbox', { name: label, exact: true });
  // focus() mira o <input> exato (mais determinístico que clicar por coordenada,
  // que pode cair no campo anterior e poluir o valor). Limpa antes de digitar.
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

  // Função (dropdown exposto como button) — abre e escolhe uma opção do seed.
  await page.getByRole('button', { name: /Função pretendida/ }).click();
  await page.waitForTimeout(1200);
  await page.getByRole('menuitem', { name: 'Bartender' }).click();
  await page.waitForTimeout(500);

  // Tipo de pessoa (segmented = botões dentro do grupo "Tipo de pessoa").
  await page.getByRole('button', { name: tipo, exact: true }).click();

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

test.describe('WebApp — pré-cadastro de profissional (CA-9)', () => {
  test('tela pública carrega sem auth', async ({ page }) => {
    await gotoApp(page, '/cadastro/profissional');
    await expect(page).toHaveURL(/\/cadastro\/profissional$/);
    await expect(page.getByText('Criar conta de profissional')).toBeVisible();
  });

  for (const tipo of ['PF', 'MEI'] as const) {
    test(`envia cadastro ${tipo} e vê a tela de recebido`, async ({ page }) => {
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
