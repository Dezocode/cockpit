// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/pinokioEnvironment.test.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Cockpit PINOKIO_CONFIG_FIELDS + sharing sentinel.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  PINOKIO_CONFIG_FIELDS,
  ensurePinokioSharingBoundary,
  applyPinokioEnvironment,
} from '../../app/server/gev/pinokioEnvironment.mjs';

test('PINOKIO_CONFIG_FIELDS includes Cockpit keys and sharing', () => {
  assert.ok(PINOKIO_CONFIG_FIELDS.includes('OPENAI_API_KEY'));
  assert.ok(PINOKIO_CONFIG_FIELDS.includes('PINOKIO_SHARE_VAR'));
  assert.equal(PINOKIO_CONFIG_FIELDS.includes('AISSTREAM_API_KEY'), false);
});

test('ensurePinokioSharingBoundary forces cockpit sentinel', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cockpit-pinokio-env-'));
  const file = path.join(dir, 'ENVIRONMENT');
  fs.writeFileSync(file, 'OPENAI_API_KEY=\nPINOKIO_SHARE_VAR=something\n', 'utf8');
  ensurePinokioSharingBoundary(file);
  const text = fs.readFileSync(file, 'utf8');
  assert.match(text, /PINOKIO_SHARE_VAR=__cockpit_sharing_disabled__/);
  assert.match(text, /PINOKIO_SHARE_CLOUDFLARE=false/);
});

test('applyPinokioEnvironment sets sharing off', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cockpit-pinokio-env-'));
  const file = path.join(dir, 'ENVIRONMENT');
  fs.writeFileSync(file, 'OPENAI_API_KEY=sk-test-NOT-A-REAL-KEY-0000\n', 'utf8');
  const prev = { ...process.env };
  try {
    applyPinokioEnvironment({ filepath: file });
    assert.equal(process.env.PINOKIO_SHARE_VAR, '__cockpit_sharing_disabled__');
    assert.equal(process.env.OPENAI_API_KEY, 'sk-test-NOT-A-REAL-KEY-0000');
  } finally {
    for (const k of Object.keys(process.env)) {
      if (!(k in prev)) delete process.env[k];
    }
    Object.assign(process.env, prev);
  }
});
