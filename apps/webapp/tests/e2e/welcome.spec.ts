import { test, expect, type Page } from '@playwright/test';

/**
 * STORY-022 — CA-11 — E2E da tela de welcome pós-aprovação (Flutter Web).
 *
 * Pré-requisito: migrações + seed (make _e2e-seed). O seed cria
 * `bemvindo.profissional@turni.local` com role=profissional, status=liberado,
 * welcome_seen_at=null → o funnel guard o leva para /welcome no primeiro login.
 *
 * Sobre semantics do Flutter Web: ver nota em rbac-login.spec.ts. `gotoApp` ativa
 * a árvore acessível para que getByText/getByRole enxerguem os widgets.
 */

const password = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';
const welcomeEmail = 'bemvindo.profissional@turni.local';

async function gotoApp(page: Page, path: string) {
  await page.goto(path);
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

async function login(page: Page, email: string) {
  await page.getByLabel('E-mail').click();
  await page.keyboard.type(email, { delay: 10 });
  await page.getByLabel('Senha', { exact: true }).click();
  await page.keyboard.type(password, { delay: 10 });
  await page.getByRole('button', { name: 'Entrar' }).click();
  await page.waitForTimeout(4000);
}

test.describe('WebApp — welcome pós-aprovação (CA-11)', () => {
  test('profissional liberado vê /welcome, segue por "Vamos lá" e cai em /completar-cadastro; 2º login pula o welcome', async ({
    page,
    context,
  }) => {
    // 1º login — cai em /welcome (status=liberado, welcome_visto=false)
    await gotoApp(page, '/login');
    await login(page, welcomeEmail);

    await expect(page).toHaveURL(/\/welcome$/);
    await expect(page.getByText('Vamos lá')).toBeVisible({ timeout: 10000 });
    // Saudação personalizada (CA-2) — o seed nomeia o usuário "Bem-Vindo Teste (seed)".
    await expect(page.getByText(/Bem-vindo\(a\), Bem-Vindo!/)).toBeVisible();

    // CTA "Vamos lá" marca welcome_visto e redireciona a /completar-cadastro (CA-4)
    await page.getByRole('button', { name: 'Vamos lá' }).click();
    await page.waitForTimeout(4000);
    await expect(page).toHaveURL(/\/completar-cadastro$/);

    // Limpa a sessão do cliente para simular um novo login do mesmo usuário.
    await context.clearCookies();
    await page.evaluate(() => window.localStorage.clear());

    // 2º login — agora welcome_visto=true, cadastro incompleto → cai DIRETO em
    // /completar-cadastro, sem passar pelo /welcome (CA-11).
    await gotoApp(page, '/login');
    await login(page, welcomeEmail);

    await expect(page).toHaveURL(/\/completar-cadastro$/);
    await expect(page).not.toHaveURL(/\/welcome$/);
  });
});
