// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/pinokioLauncherContract.test.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: paths + Cockpit registry/sentinel.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(import.meta.url);

test('pinokio/start.js is daemon loopback with path ..', () => {
  const start = require(path.join(root, 'pinokio/start.js'));
  assert.equal(start.daemon, true);
  const run = start.run[0];
  assert.equal(run.params.path, '..');
  assert.equal(run.params.env.HOST, '127.0.0.1');
  assert.match(run.params.message, /pinokio-start/);
  assert.ok(run.params.on?.[0]?.event.includes('127\\.0\\.0\\.1'));
});

test('pinokio/*.js parse under node --check contract (module load)', () => {
  for (const f of ['pinokio.js', 'install.js', 'start.js', 'update.js', 'reset.js']) {
    assert.doesNotThrow(() => require(path.join(root, 'pinokio', f)));
  }
});

test('no sudo or absolute paths in pinokio scripts', () => {
  const text = fs.readFileSync(path.join(root, 'pinokio/start.js'), 'utf8')
    + fs.readFileSync(path.join(root, 'pinokio/install.js'), 'utf8');
  assert.equal(/sudo/.test(text), false);
  assert.equal(/\/Users\//.test(text), false);
  assert.equal(/\/home\//.test(text), false);
});
