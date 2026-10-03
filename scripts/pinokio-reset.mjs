#!/usr/bin/env node
// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe scripts/pinokio-reset.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Targets app/node_modules, app/dist, app/dist-server, pinokio/.installed; credentials kept..

import { rmSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const targets = [
  path.join(ROOT, 'app', 'node_modules'),
  path.join(ROOT, 'app', 'dist'),
  path.join(ROOT, 'app', 'dist-server'),
  path.join(ROOT, 'pinokio', '.installed'),
];
for (const t of targets) {
  rmSync(t, { recursive: true, force: true });
  console.log(`[Pinokio] Removed ${path.relative(ROOT, t) || t}`);
}
console.log('[Pinokio] Reset complete. Credentials were kept. Run Install again.');
