import { test, expect } from '@playwright/test';

/**
 * STORY-016 — CA-13 — E2E de login e RBAC no Backoffice.
 *
 * Roda contra a URL do admin em homolog (BASE_URL via env ou playwright.config).
 * Credenciais via ADMIN_EMAIL / ADMIN_PASSWORD (default: seed de homolog).
 */

const adminEmail = process.env.ADMIN_SEED_EMAIL ?? 'admin@turni.local';
const adminPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';
const contratanteEmail = 'contratante.teste@turni.local';
const contratantePassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';

// ──────────────────────────────────────────────────────────────
// CA-13 (b) — Admin loga no Backoffice e vê dashboard
// ──────────────────────────────────────────────────────────────

test.describe('Backoffice — login admin (CA-13b)', () => {
  test('admin loga com sucesso e vê dashboard', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('[data-testid="screen-login-backoffice"]')).toBeVisible();

    await page.locator('[data-testid="input-email"]').fill(adminEmail);
    await page.locator('[data-testid="input-password"]').fill(adminPassword);
    await page.locator('[data-testid="btn-submit-login"]').click();

    // Após login: redireciona para '/'
    await expect(page).toHaveURL('/');
    // Dashboard mostra "Backoffice"
    await expect(page.getByText('Backoffice')).toBeVisible();
  });

  test('tela de login do admin tem campos com data-testid corretos', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('[data-testid="input-email"]')).toBeVisible();
    await expect(page.locator('[data-testid="input-password"]')).toBeVisible();
    await expect(page.locator('[data-testid="btn-submit-login"]')).toBeVisible();
  });
});

// ──────────────────────────────────────────────────────────────
// CA-13 (d) — Profissional/contratante → Backoffice = 403
// ──────────────────────────────────────────────────────────────

test.describe('Backoffice — não-admin rejeitado (CA-13d)', () => {
  test('contratante tentando logar no backoffice recebe erro', async ({ page }) => {
    await page.goto('/login');

    await page.locator('[data-testid="input-email"]').fill(contratanteEmail);
    await page.locator('[data-testid="input-password"]').fill(contratantePassword);
    await page.locator('[data-testid="btn-submit-login"]').click();

    // Deve mostrar erro ou 403 — não redireciona para '/'
    // Verifica que não chega ao dashboard
    await page.waitForTimeout(1000);
    const url = page.url();
    expect(url).not.toMatch(/\/$/);
  });
});

// ──────────────────────────────────────────────────────────────
// Audit log — verificação visual pós-login
// ──────────────────────────────────────────────────────────────

test.describe('Backoffice — logout', () => {
  test('admin consegue fazer logout e é redirecionado para /login', async ({ page }) => {
    await page.goto('/login');
    await page.locator('[data-testid="input-email"]').fill(adminEmail);
    await page.locator('[data-testid="input-password"]').fill(adminPassword);
    await page.locator('[data-testid="btn-submit-login"]').click();

    await expect(page).toHaveURL('/');

    // Logout via formulário
    await page.getByRole('button', { name: 'Sair' }).click();
    await expect(page).toHaveURL('/login');

    // Após logout, acessar '/' redireciona para /login
    await page.goto('/');
    await expect(page).toHaveURL('/login');
  });
});
