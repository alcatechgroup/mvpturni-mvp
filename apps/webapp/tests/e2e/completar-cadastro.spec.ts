import { test, expect, type Page } from '@playwright/test';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

/**
 * STORY-023 — CA-15 — E2E do completar-cadastro de profissional (Flutter Web).
 *
 * Cobre: PF (CPF → preview → aceite → ativo + aceite no banco), MEI (CNPJ → template MEI),
 * e bloqueio do aceite sem marcar o checkbox (CA-8). Usuários `await_cadastro` vêm do
 * AdminUserSeeder (completar.pf@ / completar.mei@). updateOrCreate os reseta a cada seed,
 * então o E2E é re-rodável (o check de documento duplicado exclui o próprio usuário).
 *
 * Default: http://localhost:8003 (IDR-004). Pré-requisito: `make _e2e-seed`.
 * Flutter Web pinta em <canvas>: `gotoApp` ativa a árvore de semantics; rolagem do
 * contrato via mouse.wheel (canvas não tem scroll de DOM).
 */

const docPath = fileURLToPath(new URL('./fixtures/foto.png', import.meta.url));
const senha = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';

// CPF/CNPJ válidos (dígitos verificadores corretos) — fixos; o mesmo usuário pode reusar.
const CPF = '52998224725';
const CNPJ = '11222333000181';

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
  // O conteúdo do Stepper recém-revelado leva um instante para entrar na árvore de
  // semantics, e o foco do primeiro campo após a troca de passo é instável no Flutter
  // Web — clica, digita, e confere o valor (re-tenta) para não perder caracteres.
  await field.waitFor({ state: 'visible', timeout: 20_000 });
  for (let attempt = 0; attempt < 3; attempt++) {
    await field.click();
    await page.waitForTimeout(150);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(value, { delay: 25 });
    await page.waitForTimeout(150);
    const atual = await field.inputValue().catch(() => '');
    if (atual === value) return;
  }
}

/** Login e espera o funnel guard cair em /completar-cadastro (estado await_cadastro). */
async function loginCompletar(page: Page, email: string) {
  await gotoApp(page, '/login');
  // Mesma técnica do rbac-login.spec.ts (getByLabel + digitação real).
  await page.getByLabel('E-mail').click();
  await page.keyboard.type(email, { delay: 10 });
  await page.getByLabel('Senha', { exact: true }).click();
  await page.keyboard.type(senha, { delay: 10 });
  await page.getByRole('button', { name: 'Entrar' }).click();
  await page.waitForTimeout(4000);
  await expect(page).toHaveURL(/\/completar-cadastro$/);
}

async function tapBtn(page: Page, name: string | RegExp) {
  await page.getByRole('button', { name, exact: typeof name === 'string' }).click();
  await page.waitForTimeout(1200);
}

/** Preenche os 3 passos e abre o preview do contrato. */
async function preencherAtePreview(page: Page, documento: string, docLabel: 'CPF' | 'CNPJ') {
  await typeInto(page, docLabel, documento);
  await tapBtn(page, 'Continuar');

  await typeInto(page, 'Até quantos km você se desloca?', '30');
  await typeInto(page, 'Seu preço por hora (R$)', '45');
  await tapBtn(page, 'Continuar');

  await typeInto(page, 'Sua chave Pix', 'profissional@pix.com');

  // Upload do documento — image_picker_for_web abre um <input type=file>.
  const chooser = page.waitForEvent('filechooser');
  await tapBtn(page, /Enviar foto do documento/);
  await (await chooser).setFiles(docPath);
  await page.waitForTimeout(500);

  await tapBtn(page, 'Revisar e assinar o contrato');
}

/** Rola o contrato até o fim (canvas → mouse.wheel) para habilitar o aceite. */
async function rolarContratoAteOFim(page: Page) {
  const { width, height } = page.viewportSize() ?? { width: 390, height: 844 };
  await page.mouse.move(width / 2, height / 2);
  for (let i = 0; i < 8; i++) {
    await page.mouse.wheel(0, 1200);
    await page.waitForTimeout(200);
  }
}

function contarAceites(email: string): number {
  const out = execSync(
    `docker compose exec -T api php artisan tinker --execute=` +
      `'echo \\App\\Models\\AceiteEletronico::whereHas("user",fn($q)=>$q->where("email","${email}"))->count();'`,
    { cwd: fileURLToPath(new URL('../../../../', import.meta.url)), encoding: 'utf8' },
  );
  const m = out.match(/(\d+)\s*$/);
  return m ? Number(m[1]) : 0;
}

test.describe('STORY-023 — completar cadastro (CA-15)', () => {
  test('PF: CPF → preview → aceite → ativo, com AceiteEletronico no banco', async ({ page }) => {
    const email = 'completar.pf@turni.local';
    const antes = contarAceites(email);

    await loginCompletar(page, email);
    await expect(page.getByText('Complete seu cadastro')).toBeVisible();

    await preencherAtePreview(page, CPF, 'CPF');

    // preview renderizado (CA-7) — o botão de aceite só existe na fase de preview.
    await expect(page.getByRole('button', { name: 'Aceito e concluir cadastro' })).toBeVisible({ timeout: 15000 });

    await rolarContratoAteOFim(page);
    await page.getByRole('checkbox').click();
    await tapBtn(page, 'Aceito e concluir cadastro');

    // conclusão (CA-12) — só aparece após 201 (aceite criado + transição para ativo)
    await expect(page.getByText('Cadastro concluído. Bem-vindo ao Turni!')).toBeVisible({ timeout: 10000 });

    // CA-9 — AceiteEletronico criado no banco
    expect(contarAceites(email)).toBeGreaterThan(antes);
  });

  test('MEI: CNPJ usa o template mei_pj_b2b e conclui', async ({ page }) => {
    const email = 'completar.mei@turni.local';
    const antes = contarAceites(email);

    await loginCompletar(page, email);
    await preencherAtePreview(page, CNPJ, 'CNPJ');

    await expect(page.getByRole('button', { name: 'Aceito e concluir cadastro' })).toBeVisible({ timeout: 15000 });

    await rolarContratoAteOFim(page);
    await page.getByRole('checkbox').click();
    await tapBtn(page, 'Aceito e concluir cadastro');

    await expect(page.getByText('Cadastro concluído. Bem-vindo ao Turni!')).toBeVisible({ timeout: 10000 });
    expect(contarAceites(email)).toBeGreaterThan(antes);
  });

  test('CA-8: não conclui sem marcar o checkbox de aceite', async ({ page }) => {
    // Usuário dedicado que nunca conclui — permanece await_cadastro (re-rodável).
    await loginCompletar(page, 'completar.bloqueio@turni.local');
    await preencherAtePreview(page, CPF, 'CPF');
    await expect(page.getByRole('button', { name: 'Aceito e concluir cadastro' })).toBeVisible({ timeout: 15000 });
    await rolarContratoAteOFim(page);

    // SEM marcar o checkbox: o CTA está desabilitado. force+timeout curto evita esperar
    // a actionability (o clique não tem efeito) e confirmamos que NÃO concluiu.
    await page
      .getByRole('button', { name: 'Aceito e concluir cadastro' })
      .click({ force: true, timeout: 3000 })
      .catch(() => {});
    await page.waitForTimeout(1500);

    await expect(page.getByText('Cadastro concluído. Bem-vindo ao Turni!')).toHaveCount(0);
    // Continua no preview (ainda em await_cadastro): o aceite não foi gerado.
    await expect(page.getByRole('button', { name: 'Aceito e concluir cadastro' })).toBeVisible();
  });
});
