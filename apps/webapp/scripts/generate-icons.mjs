#!/usr/bin/env node
// Regenera os PNGs de ícone do PWA a partir dos SVGs-fonte versionados.
//
// Fonte da verdade: apps/webapp/web/icons/source/*.svg (STORY-041 / IDR-020 §8).
// Esta é uma utility de MANUTENÇÃO — NÃO faz parte do build do app (`flutter build web`).
// Rode apenas quando os SVGs-fonte mudarem.
//
//   cd apps/webapp && npm run icons
//
// Requisito: devDependency `sharp` (rasterizador SVG→PNG, libvips). `npm install` já a traz.

import sharp from 'sharp';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const webDir = join(here, '..', 'web');
const srcDir = join(webDir, 'icons', 'source');

// source SVG → [ {out, size}, ... ]
const targets = [
  { svg: 'icon.svg', outputs: [
    { out: 'icons/Icon-192.png', size: 192 },
    { out: 'icons/Icon-512.png', size: 512 },
  ] },
  { svg: 'icon-maskable.svg', outputs: [
    { out: 'icons/Icon-maskable-192.png', size: 192 },
    { out: 'icons/Icon-maskable-512.png', size: 512 },
  ] },
  // apple-touch-icon: o iOS aplica a própria máscara e compõe transparência sobre PRETO.
  // Por isso sai de uma fonte full-bleed e é ACHATADO sobre brandGreen → zero alpha.
  { svg: 'apple-touch-icon.svg', flatten: '#00A868', outputs: [
    { out: 'icons/apple-touch-icon.png', size: 180 },
  ] },
  { svg: 'favicon.svg', outputs: [
    { out: 'favicon.png', size: 32 },
  ] },
];

let count = 0;
for (const { svg, outputs, flatten } of targets) {
  const svgPath = join(srcDir, svg);
  for (const { out, size } of outputs) {
    const outPath = join(webDir, out);
    // density alta antes do resize → bordas limpas mesmo em tamanhos pequenos.
    let pipe = sharp(svgPath, { density: 384 }).resize(size, size, { fit: 'cover' });
    if (flatten) pipe = pipe.flatten({ background: flatten });
    await pipe.png({ compressionLevel: 9 }).toFile(outPath);
    console.log(`  ${svg} → ${out} (${size}×${size})${flatten ? ' [opaco]' : ''}`);
    count++;
  }
}
console.log(`\n✓ ${count} PNGs regenerados a partir de ${targets.length} SVGs-fonte.`);
