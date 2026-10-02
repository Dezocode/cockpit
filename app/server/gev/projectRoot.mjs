// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe scripts/project-root.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: COCKPIT_PROJECT_ROOT; walk-up to repo markers (works from server/gev and dist-server/gev).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

function looksLikeRepoRoot(dir) {
  return (
    fs.existsSync(path.join(dir, 'bin', 'cockpit')) ||
    fs.existsSync(path.join(dir, 'install.sh')) ||
    fs.existsSync(path.join(dir, 'pinokio', 'start.js'))
  );
}

function walkUp(start) {
  let dir = path.resolve(start);
  for (let i = 0; i < 8; i += 1) {
    if (looksLikeRepoRoot(dir)) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return path.resolve(start);
}

/** Resolve the explicit CLI project directory, defaulting to the Cockpit repo root. */
export function projectRoot(moduleUrl, environment = process.env) {
  if (environment.COCKPIT_PROJECT_ROOT) {
    return path.resolve(environment.COCKPIT_PROJECT_ROOT);
  }
  const here = path.dirname(fileURLToPath(moduleUrl));
  return walkUp(here);
}
