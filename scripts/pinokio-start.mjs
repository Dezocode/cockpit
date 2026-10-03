#!/usr/bin/env node
// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe scripts/pinokio-start.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Spawn dist-server with loopback + SERVE_UI; LOCAL_TRUST set by pinokio/start.js env; Ready URL regex unchanged..

import { realpathSync, existsSync } from 'node:fs';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyPinokioEnvironment } from './pinokio-environment.mjs';
import { isDirectInvocation } from './pinokio-install.mjs';
import { validatePinokioSharing } from './pinokio-preflight.mjs';

const MODULE_PATH = fileURLToPath(import.meta.url);
const ROOT = realpathSync(path.resolve(path.dirname(MODULE_PATH), '..'));

function launchPort(value) {
  const port = Number.parseInt(value, 10);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('Pinokio did not supply a valid local port.');
  }
  return port;
}

async function start() {
  applyPinokioEnvironment();
  validatePinokioSharing();
  const port = launchPort(process.env.PORT);
  process.env.COCKPIT_LAUNCHER = 'pinokio';
  process.env.COCKPIT_WEB_HOST = '127.0.0.1';
  process.env.COCKPIT_WEB_PORT = String(port);
  process.env.COCKPIT_SERVE_UI = '1';
  console.log('[Pinokio] Local-only launch.');

  const entry = path.join(ROOT, 'app', 'dist-server', 'index.js');
  if (!existsSync(entry)) {
    throw new Error('app/dist-server/index.js is missing. Run Install first.');
  }
  const child = spawn(process.execPath, [entry], {
    cwd: ROOT,
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const forward = (buf) => {
    const text = buf.toString();
    process.stdout.write(text);
  };
  child.stdout.on('data', forward);
  child.stderr.on('data', (buf) => process.stderr.write(buf));
  // Ready line for Pinokio regex (loopback proof is ss/lsof on pid, not this URL).
  console.log(`[Pinokio] Ready at http://127.0.0.1:${port}/`);
  console.log(`[Pinokio] pid=${child.pid}`);

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.once(signal, () => {
      child.kill(signal);
      process.exit(0);
    });
  }
  child.on('exit', (code) => process.exit(code ?? 1));
}

if (isDirectInvocation(process.argv[1], MODULE_PATH)) {
  start().catch((error) => {
    console.error(`[Pinokio] Start refused: ${error.message}`);
    process.exitCode = 1;
  });
}
