#!/usr/bin/env node
// Branding do PWA por ambiente (ícone + nome). Roda ANTES de `flutter build web`
// no pipeline de deploy (release.yml / deploy-stage.yml): recolore os ícones e
// ajusta manifest.json/index.html conforme o ambiente. Idempotente e reversível
// entre ambientes (sempre parte dos SVGs-fonte verdes).
//
//   node scripts/brand-webapp.mjs <production|homolog|stage>
//
// Por que existe: o build do WebApp é único por pipeline e os assets web são
// estáticos. Para diferenciar visualmente os ambientes instalados como PWA
// (prod verde, stage ciano, homolog azul) + sufixo de ambiente no nome, tingimos
// os ícones e reescrevemos nome/theme-color neste ponto. Prod = sem sufixo, verde
// brandGreen (no-op visual sobre o versionado). Fonte da verdade dos desenhos:
// web/icons/source/*.svg (STORY-041 / IDR-020 §8) — NÃO são tocados aqui.

import sharp from 'sharp';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Cor base dos SVGs-fonte (brandGreen, DDR-001). Trocada pela cor do ambiente.
const BRAND_GREEN = '#00A868';

// Ambiente → cor do ícone/theme + sufixo do nome. Tons na família do brandGreen
// (mesma saturação/luminância, matiz girando verde → ciano → azul).
const ENVS = {
  production: { color: BRAND_GREEN, suffix: '' },
  homolog: { color: '#1769C0', suffix: ' Homol' }, // azul
  stage: { color: '#00A6B0', suffix: ' Stage' }, // ciano
};

const arg = (process.argv[2] || '').toLowerCase();
const key = arg === 'prod' ? 'production' : arg;
const cfg = ENVS[key];
if (!cfg) {
  console.error(
    `Ambiente inválido: "${process.argv[2]}". Use production|homolog|stage.`,
  );
  process.exit(1);
}

const here = dirname(fileURLToPath(import.meta.url));
const webDir = join(here, '..', 'web');
const srcDir = join(webDir, 'icons', 'source');
const appName = `Turni${cfg.suffix}`;

// ── Ícones: recolore os SVGs-fonte em memória e rasteriza (sharp) ─────────────
const targets = [
  {
    svg: 'icon.svg',
    outputs: [
      ['icons/Icon-192.png', 192],
      ['icons/Icon-512.png', 512],
    ],
  },
  {
    svg: 'icon-maskable.svg',
    outputs: [
      ['icons/Icon-maskable-192.png', 192],
      ['icons/Icon-maskable-512.png', 512],
    ],
  },
  // apple-touch: iOS compõe transparência sobre PRETO → achata sobre a cor do env.
  {
    svg: 'apple-touch-icon.svg',
    flatten: cfg.color,
    outputs: [['icons/apple-touch-icon.png', 180]],
  },
  { svg: 'favicon.svg', outputs: [['favicon.png', 32]] },
];

for (const { svg, outputs, flatten } of targets) {
  let raw = await readFile(join(srcDir, svg), 'utf8');
  raw = raw.replaceAll(BRAND_GREEN, cfg.color);
  const buf = Buffer.from(raw);
  for (const [out, size] of outputs) {
    // density alta antes do resize → bordas limpas em tamanhos pequenos.
    let pipe = sharp(buf, { density: 384 }).resize(size, size, { fit: 'cover' });
    if (flatten) pipe = pipe.flatten({ background: flatten });
    await pipe.png({ compressionLevel: 9 }).toFile(join(webDir, out));
  }
}

// ── manifest.json: name, short_name, theme_color ─────────────────────────────
const manifestPath = join(webDir, 'manifest.json');
const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
manifest.name = appName;
manifest.short_name = appName;
manifest.theme_color = cfg.color;
await writeFile(manifestPath, `${JSON.stringify(manifest, null, 4)}\n`);

// ── index.html: theme-color, <title>, apple-mobile-web-app-title ─────────────
const indexPath = join(webDir, 'index.html');
let html = await readFile(indexPath, 'utf8');
html = html.replace(
  /(<meta name="theme-color" content=")[^"]*(">)/,
  `$1${cfg.color}$2`,
);
html = html.replace(/(<title>)[^<]*(<\/title>)/, `$1${appName}$2`);
html = html.replace(
  /(<meta name="apple-mobile-web-app-title" content=")[^"]*(">)/,
  `$1${appName}$2`,
);
await writeFile(indexPath, html);

console.log(`✓ Branding "${key}": cor ${cfg.color}, nome "${appName}"`);
