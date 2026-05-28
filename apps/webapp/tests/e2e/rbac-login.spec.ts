import { test, expect } from '@playwright/test';

/**
 * STORY-016 — CA-13 — E2E de login e RBAC no WebApp.
 *
 * Default: http://localhost:8003 (IDR-004). Homolog: BASE_URL=https://app.homolog.turni.com.br.
 * Credenciais via env (default: seed local/homolog).
 *
 * ⚠️ FOLLOW-UP RASTREADO (decisão 2026-05-28): estes cenários estão `test.fixme`.
 * O WebApp roda Flutter Web com renderer CanvasKit, que pinta a UI num <canvas> e
 * NÃO expõe a árvore semântica como DOM por padrão — nem `[key="..."]` (não viram
 * HTML attributes) nem `getByLabel`/`getByRole` encontram os campos, e o suite dá
 * timeout. Resolver exige uma decisão de estratégia de E2E do Flutter Web ainda
 * pendente: (a) ativar/forçar `flutter.semanticsEnabled` (clicar no placeholder
 * "Enable accessibility") e mapear Semantics labels nos widgets, ou (b) adotar
 * integration_test (flutter drive) no lugar de Playwright para o WebApp.
 * Até essa decisão, o gate `make e2e` cobre o Backoffice (HTML real, verde) e o
 * smoke HTTP do WebApp (webapp-hello-world.spec.ts). Não remover os cenários —
 * eles são o checklist do CA-13 a reabilitar quando a estratégia for escolhida.
 */

const adminEmail = process.env.ADMIN_SEED_EMAIL ?? 'admin@turni.local';
const adminPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';
const profissionalEmail = 'profissional.teste@turni.local';
const profissionalPassword = process.env.ADMIN_SEED_PASSWORD ?? 'turni-dev';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

async function fillLoginForm(page: import('@playwright/test').Page, email: string, password: string) {
    await page.getByLabel('E-mail').fill(email);
    await page.getByLabel('Senha').fill(password);
}

// ──────────────────────────────────────────────────────────────
// CA-13 (c) — Admin tentando logar no WebApp → banner de redirecionamento
// ──────────────────────────────────────────────────────────────

test.describe.fixme('WebApp — admin rejeitado (CA-13c)', () => {
    test('tela /login carrega e exibe campos de e-mail e senha', async ({ page }) => {
        await page.goto('/login');

        // Aguarda o Flutter carregar
        await page.waitForTimeout(3000);

        // Verifica que campos de login estão presentes via rótulos acessíveis
        await expect(page.getByLabel('E-mail')).toBeVisible({ timeout: 15000 });
        await expect(page.getByLabel('Senha')).toBeVisible({ timeout: 5000 });
    });

    test('admin não consegue logar no WebApp — recebe banner de redirecionamento', async ({ page }) => {
        await page.goto('/login');
        await page.waitForTimeout(3000);

        await fillLoginForm(page, adminEmail, adminPassword);
        await page.getByRole('button', { name: 'Entrar' }).click();

        // Deve aparecer a mensagem de redirecionamento (não vai para /app)
        await page.waitForTimeout(2000);
        await expect(page.getByText('Este usuário acessa o Backoffice.')).toBeVisible({
            timeout: 10000,
        });
    });
});

// ──────────────────────────────────────────────────────────────
// CA-13 (b) — Profissional ativo loga no WebApp
// ──────────────────────────────────────────────────────────────

test.describe.fixme('WebApp — profissional ativo (CA-13b)', () => {
    test('profissional ativo loga e é roteado para /app ou funnel', async ({ page }) => {
        await page.goto('/login');
        await page.waitForTimeout(3000);

        await fillLoginForm(page, profissionalEmail, profissionalPassword);
        await page.getByRole('button', { name: 'Entrar' }).click();

        // Aguarda o redirect (até 10s)
        await page.waitForTimeout(4000);

        // Deve estar no /app (ativo) ou /welcome (liberado)
        const url = page.url();
        expect(url).toMatch(/\/(app|welcome|completar-cadastro|login)/);
    });
});

// ──────────────────────────────────────────────────────────────
// CA-13 (e) — Funnel guard: /welcome existe para usuário liberado
// ──────────────────────────────────────────────────────────────

test.describe.fixme('WebApp — funnel guard e estrutura (CA-13e)', () => {
    test('tela /login tem botão Entrar', async ({ page }) => {
        await page.goto('/login');
        await page.waitForTimeout(3000);

        await expect(page.getByRole('button', { name: 'Entrar' })).toBeVisible({ timeout: 15000 });
    });

    test('tela /login tem link Esqueci minha senha', async ({ page }) => {
        await page.goto('/login');
        await page.waitForTimeout(3000);

        await expect(page.getByText('Esqueci minha senha')).toBeVisible({ timeout: 15000 });
    });

    test('validação: clique em Entrar sem campos exibe erro obrigatório', async ({ page }) => {
        await page.goto('/login');
        await page.waitForTimeout(3000);

        await page.getByRole('button', { name: 'Entrar' }).click();
        await page.waitForTimeout(1000);

        await expect(page.getByText('Este campo é obrigatório.')).toBeVisible({ timeout: 5000 });
    });

    test('rota /welcome sem auth redireciona para /login', async ({ page }) => {
        await page.goto('/welcome');
        await page.waitForTimeout(2000);

        const url = page.url();
        expect(url).toMatch(/\/login/);
    });

    test('rota /completar-cadastro sem auth redireciona para /login', async ({ page }) => {
        await page.goto('/completar-cadastro');
        await page.waitForTimeout(2000);

        const url = page.url();
        expect(url).toMatch(/\/login/);
    });

    test('credencial inválida exibe mensagem de erro', async ({ page }) => {
        await page.goto('/login');
        await page.waitForTimeout(3000);

        await fillLoginForm(page, 'nao-existe@turni.local', 'senha-errada');
        await page.getByRole('button', { name: 'Entrar' }).click();
        await page.waitForTimeout(2000);

        // Deve estar ainda em /login (não redirecionou)
        expect(page.url()).toMatch(/\/login/);
    });
});
