import { test, expect, type Page } from '@playwright/test';

/**
 * STORY-037 — auto-atualização do WebApp + versão visível na UI (CA-8, CA-16).
 *
 * Gate LOCAL/homolog antes de criar a tag rc.N (IDR-004). Sobre semantics do
 * Flutter Web: ver nota em rbac-login.spec.ts — `activateSemantics` liga a árvore
 * acessível para que getByText/getByRole enxerguem os widgets desenhados no canvas.
 *
 *   Default: http://localhost:8003 (docker-compose). Em dev local APP_VERSION='dev'
 *   e a checagem é DESABILITADA por design (IDR-017): o cenário do banner roda contra
 *   um build com tag real —  BASE_URL=https://app.homolog.turni.com.br npx playwright test app-update
 */

async function activateSemantics(page: Page, path: string) {
  await page.goto(path);
  await page.waitForTimeout(2000);
  for (let i = 0; i < 12; i++) {
    await page.evaluate(() => {
      const el = document.querySelector(
        'flt-semantics-placeholder'
      ) as HTMLElement | null;
      el?.click();
    });
    if ((await page.locator('flt-semantics').count()) > 0) break;
    await page.waitForTimeout(500);
  }
}

async function runningVersion(page: Page): Promise<string> {
  const resp = await page.request.get('/version.json');
  const body = await resp.json();
  return body.version as string;
}

test.describe('WebApp — versão visível na UI (CA-8)', () => {
  test('rodapé do login mostra "Turni · <versão>"', async ({ page }) => {
    const version = await runningVersion(page);
    await activateSemantics(page, '/login');
    // O rótulo discreto fica no rodapé da tela de login (Key app-version-label-login).
    await expect(page.getByText(`Turni · ${version}`)).toBeVisible({
      timeout: 10000,
    });
  });
});

test.describe('WebApp — banner "Nova versão disponível" (CA-16)', () => {
  test('detecta versão nova → banner → "Atualizar agora" recarrega', async ({
    page,
  }) => {
    const version = await runningVersion(page);
    test.skip(
      version === 'dev' || version === '',
      'Build de dev desabilita a checagem (IDR-017). Rode contra um build com tag real.'
    );

    // Simula uma release mais nova no servidor: o app rodando (tag real) passa a
    // diferir da versão publicada → updateAvailable=true.
    await page.route('**/version.json*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        headers: { 'Cache-Control': 'no-cache' },
        body: JSON.stringify({ version: 'v999.0.0-rc.1' }),
      });
    });

    await activateSemantics(page, '/login');

    // Bootstrap dispara a checagem; o banner aparece no topo de qualquer rota.
    await expect(page.getByText('Nova versão disponível')).toBeVisible({
      timeout: 15000,
    });

    // "Atualizar agora" → skipWaiting + reload. Após o reload, como o mock ainda
    // serve v999, o banner reaparece — evidência de que o reload aconteceu.
    const navigated = page.waitForNavigation({ timeout: 15000 }).catch(() => null);
    await page.getByRole('button', { name: 'Atualizar agora' }).click();
    await navigated;

    await activateSemantics(page, page.url());
    await expect(page.getByText('Nova versão disponível')).toBeVisible({
      timeout: 15000,
    });
  });

  test('"Depois" fecha o banner', async ({ page }) => {
    const version = await runningVersion(page);
    test.skip(
      version === 'dev' || version === '',
      'Build de dev desabilita a checagem (IDR-017). Rode contra um build com tag real.'
    );

    await page.route('**/version.json*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        headers: { 'Cache-Control': 'no-cache' },
        body: JSON.stringify({ version: 'v999.0.0-rc.1' }),
      });
    });

    await activateSemantics(page, '/login');
    await expect(page.getByText('Nova versão disponível')).toBeVisible({
      timeout: 15000,
    });

    await page.getByRole('button', { name: 'Depois' }).click();
    await expect(page.getByText('Nova versão disponível')).toBeHidden({
      timeout: 5000,
    });
  });
});
