#!/usr/bin/env node
// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe scripts/pinokio-install.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: win32 WSL guard; install via get-cockpit.sh --from-dir; doctor; .installed 0600..

import { realpathSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyPinokioEnvironment } from './pinokio-environment.mjs';

const MODULE_PATH = fileURLToPath(import.meta.url);
const ROOT = realpathSync(path.resolve(path.dirname(MODULE_PATH), '..'));
const READY_FILE = path.join(ROOT, 'pinokio', '.installed');

export function runChecked(command, args, { shell = false } = {}) {
  const result = spawnSync(command, args, {
    cwd: ROOT,
    env: { ...process.env, PUPPETEER_SKIP_DOWNLOAD: '1', COCKPIT_INSTALL_WEB_BUILD: '1' },
    shell,
    stdio: 'inherit',
  });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}

export function installPinokioDependencies() {
  if (process.platform === 'win32') {
    console.error('[Pinokio] Windows is not supported. Install Cockpit inside WSL2 (Ubuntu), then relaunch from there.');
    process.exit(1);
  }
  applyPinokioEnvironment();
  rmSync(READY_FILE, { force: true });
  runChecked('bash', [path.join(ROOT, 'scripts', 'get-cockpit.sh'), '--from-dir', ROOT]);

  const doctor = spawnSync(
    process.execPath,
    [path.join(ROOT, 'app', 'server', 'gev', 'doctor.mjs'), '--json'],
    { cwd: ROOT, encoding: 'utf8', env: process.env },
  );
  if (doctor.stdout) process.stdout.write(doctor.stdout);
  if (doctor.stderr) process.stderr.write(doctor.stderr);
  if (doctor.status !== 0) {
    console.error('[Pinokio] Doctor reported required failures. Fix them, then Install again.');
    process.exit(doctor.status || 1);
  }

  writeFileSync(READY_FILE, `${new Date().toISOString()}\n`, { mode: 0o600 });
  console.log('[Pinokio] Installation ready. Return to Pinokio and choose Start.');
}

export function isDirectInvocation(
  invokedPath = process.argv[1],
  modulePath = MODULE_PATH,
) {
  if (typeof invokedPath !== 'string' || invokedPath.length === 0) return false;
  if (typeof modulePath !== 'string' || modulePath.length === 0) return false;
  try {
    return realpathSync(path.resolve(invokedPath)) === realpathSync(path.resolve(modulePath));
  } catch {
    return path.resolve(invokedPath) === path.resolve(modulePath);
  }
}

if (isDirectInvocation()) {
  installPinokioDependencies();
}
