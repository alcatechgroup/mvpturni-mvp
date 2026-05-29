import { test, expect, type Page } from '@playwright/test';

/**
 * STORY-016 — CA-13 — E2E de login e RBAC no WebApp (Flutter Web).
 *
 * Default: http://localhost:8003 (IDR-004). Homolog: BASE_URL=https://app.homolog.turni.com.br.
 * Credenciais via env (default: seed local/homolog). Pré-requisito: migrações + seed.
 *
 * Flutter Web/CanvasKit pinta a UI num <canvas> — a árvore acessível (DOM) só é
 * construída depois de ativar o placeholder "Enable accessibility". `gotoLogin()`
 * faz isso, e a partir daí `getByLabel`/`getByRole`/`getByText` enxergam os widgets
 * (TextFormField vira <input> com aria-label; botões e textos viram nós semânticos).
 * O app usa usePathUrlStrategy() (main.dart), então /login, /welcome, /app são paths
 * reais — sem isso a navegação caía sempre na tela inicial.
 */

const adminEmail = process.env.ADMIN_SEED_EMAIL ?? 'admin@turni.local';
const adminPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';
const profissionalEmail = 'profissional.teste@turni.local';
const profissionalPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

/** Navega para uma rota e ativa a árvore de semantics do Flutter Web. */
async function gotoApp(page: Page, path: string) {
  await page.goto(path);
  await page.waitForTimeout(2000); // boot inicial do CanvasKit
  // Ativa semantics com retry: o placeholder "Enable accessibility" só responde
  // depois que o Flutter terminou de subir; tentamos até a árvore (flt-semantics)
  // existir, em vez de confiar num sleep fixo (flaky sob carga).
  for (let i = 0; i < 12; i++) {
    await page.evaluate(() => {
      const el = document.querySelector('flt-semantics-placeholder') as HTMLElement | null;
      el?.click();
    });
    if ((await page.locator('flt-semantics').count()) > 0) break;
    await page.waitForTimeout(500);
  }
}

async function fillLoginForm(page: Page, email: string, password: string) {
  // `fill()` no <input> de semantics não sincroniza com o TextEditingController do
  // Flutter — é preciso focar e digitar de verdade (eventos de teclado reais).
  await page.getByLabel('E-mail').click();
  await page.keyboard.type(email, { delay: 10 });
  await page.getByLabel('Senha', { exact: true }).click();
  await page.keyboard.type(password, { delay: 10 });
}

async function submitLogin(page: Page) {
  await page.getByRole('button', { name: 'Entrar' }).click();
  await page.waitForTimeout(4000);
}

// ──────────────────────────────────────────────────────────────
// Estrutura da tela de login (CA-5)
// ──────────────────────────────────────────────────────────────

test.describe('WebApp — tela de login (CA-5)', () => {
  test('exibe campos e-mail, senha, link de recuperação e botão Entrar', async ({ page }) => {
    await gotoApp(page, '/login');

    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByLabel('E-mail')).toBeVisible();
    await expect(page.getByLabel('Senha', { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Entrar' })).toBeVisible();
    await expect(page.getByText('Esqueci minha senha')).toBeVisible();
  });

  test('validação: submeter vazio exibe erro de campo obrigatório', async ({ page }) => {
    await gotoApp(page, '/login');

    await submitLogin(page);
    await expect(page.getByText('Este campo é obrigatório.')).toBeVisible({ timeout: 5000 });
  });

  test('credencial inválida não autentica — permanece em /login', async ({ page }) => {
    await gotoApp(page, '/login');

    await fillLoginForm(page, 'nao-existe@turni.local', 'senha-errada');
    await submitLogin(page);

    await expect(page).toHaveURL(/\/login$/);
  });
});

// ──────────────────────────────────────────────────────────────
// CA-13 (b) — Profissional ativo loga e cai em rota interna
// ──────────────────────────────────────────────────────────────

test.describe('WebApp — profissional ativo (CA-13b)', () => {
  test('profissional ativo loga e é roteado para a home (root)', async ({ page }) => {
    await gotoApp(page, '/login');

    await fillLoginForm(page, profissionalEmail, profissionalPassword);
    await submitLogin(page);

    // Ativo cai na home pós-login (root `/`); demais estados, nas rotas de funil.
    // Em qualquer caso, NÃO permanece em /login.
    await expect(page).not.toHaveURL(/\/login$/);
  });
});

// ──────────────────────────────────────────────────────────────
// CA-13 (c) — Admin é rejeitado no WebApp com banner para o Backoffice
// ──────────────────────────────────────────────────────────────

test.describe('WebApp — admin rejeitado (CA-13c)', () => {
  test('admin não loga no WebApp — vê banner de redirecionamento', async ({ page }) => {
    await gotoApp(page, '/login');

    await fillLoginForm(page, adminEmail, adminPassword);
    await submitLogin(page);

    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByText('Este usuário acessa o Backoffice.')).toBeVisible({
      timeout: 10000,
    });
  });
});

// ──────────────────────────────────────────────────────────────
// CA-10/CA-11 — Funnel guard: rotas internas exigem auth
// ──────────────────────────────────────────────────────────────

test.describe('WebApp — funnel guard (CA-10/CA-11)', () => {
  test('rota /welcome sem auth redireciona para /login', async ({ page }) => {
    await gotoApp(page, '/welcome');
    await expect(page).toHaveURL(/\/login$/);
  });

  test('rota /completar-cadastro sem auth redireciona para /login', async ({ page }) => {
    await gotoApp(page, '/completar-cadastro');
    await expect(page).toHaveURL(/\/login$/);
  });
});

// ──────────────────────────────────────────────────────────────
// Navegação: root protegido + atalho "Criar conta" (ajustes 2026-05-29)
// ──────────────────────────────────────────────────────────────

test.describe('WebApp — navegação (root / criar conta)', () => {
  test('root `/` sem auth redireciona para /login', async ({ page }) => {
    await gotoApp(page, '/');
    await expect(page).toHaveURL(/\/login$/);
  });

  test('link "Cadastre-se" no login leva ao pré-cadastro', async ({ page }) => {
    await gotoApp(page, '/login');
    await page.getByRole('button', { name: 'Não tem conta? Cadastre-se' }).click();
    await page.waitForTimeout(1500);
    await expect(page).toHaveURL(/\/cadastro\/profissional$/);
  });

  test('/info carrega a tela informativa pública sem auth', async ({ page }) => {
    const response = await page.goto('/info');
    expect(response?.status()).toBe(200);
    await expect(page).toHaveURL(/\/info$/);
  });
});
