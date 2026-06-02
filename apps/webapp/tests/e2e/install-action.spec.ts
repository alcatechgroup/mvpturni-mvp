import { test, expect, type Page } from '@playwright/test';

/**
 * STORY-042 — ação "Instalar app" no WebApp (CA-17).
 *
 * Cenário web-platform (depende de `window.turniInstall` montado pelo script
 * pré-Flutter + da árvore de semantics do Flutter Web). Como o `app-update.spec.ts`,
 * fica em target Playwright próprio (NÃO-gating) — mas, ao contrário do auto-update,
 * a instalabilidade independe da versão de build (funciona em dev), então roda contra
 * o build servido em :8003.
 *
 * A instalabilidade real vem de `beforeinstallprompt`, que o Chromium headless não
 * dispara sozinho. Aqui injetamos um evento sintético APÓS o boot — exercitando o
 * listener real do `index.html` (preventDefault + guarda + CustomEvent) e o bridge
 * Dart (lib/core/install) que reabre a ação. Sobre `activateSemantics`: ver
 * app-update.spec.ts / rbac-login.spec.ts.
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

/** Dispara um `beforeinstallprompt` sintético no listener real do index.html. */
async function fireBeforeInstallPrompt(page: Page) {
  await page.evaluate(() => {
    const e = new Event('beforeinstallprompt') as Event & {
      prompt?: () => void;
      userChoice?: Promise<{ outcome: string }>;
    };
    e.prompt = () => {};
    e.userChoice = Promise.resolve({ outcome: 'accepted' });
    window.dispatchEvent(e);
  });
}

test.describe('WebApp — ação "Instalar app" no login (CA-17)', () => {
  test('card aparece quando isInstallable=true (beforeinstallprompt)', async ({
    page,
  }) => {
    await activateSemantics(page, '/login');

    // Antes do evento, não há prompt nativo guardado → card escondido.
    await expect(page.getByText('Instalar app na tela inicial')).toBeHidden({
      timeout: 5000,
    });

    // O script real captura o evento, marca isInstallable=true e emite o
    // CustomEvent que o controller Dart escuta → card aparece.
    await fireBeforeInstallPrompt(page);
    expect(
      await page.evaluate(() => (window as any).turniInstall?.isInstallable)
    ).toBe(true);

    await expect(page.getByText('Instalar app na tela inicial')).toBeVisible({
      timeout: 10000,
    });
  });
});
