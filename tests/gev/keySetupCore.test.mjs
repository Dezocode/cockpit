// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/keySetupCore.test.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Cockpit KEY_SETUP_KEYS registry assertions.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  KEY_SETUP_KEYS,
  admitKeySetupRequest,
  isKeySetupExternallyManaged,
  keySetupStatus,
  knownKeySetupEnvVars,
  upsertDotenvValues,
  validateKeySetupUpdates,
} from '../../app/server/gev/keySetupCore.mjs';

test('registry has Cockpit providers and hides server-only rows', () => {
  const ids = KEY_SETUP_KEYS.map((k) => k.id);
  assert.deepEqual(ids, ['openai', 'anthropic', 'xai', 'ntfy', 'notify', 'telegram']);
  assert.ok(KEY_SETUP_KEYS.find((k) => k.id === 'telegram')?.hidden);
  assert.ok(KEY_SETUP_KEYS.find((k) => k.id === 'notify')?.hidden);
  assert.ok(KEY_SETUP_KEYS.find((k) => k.id === 'openai')?.providers?.includes('codex'));
});

test('knownKeySetupEnvVars covers registry', () => {
  const known = knownKeySetupEnvVars();
  assert.ok(known.has('OPENAI_API_KEY'));
  assert.ok(known.has('COCKPIT_TELEGRAM_BOT_TOKEN'));
});

test('keySetupStatus is presence-only and skips hidden', () => {
  const status = keySetupStatus({ OPENAI_API_KEY: 'sk-test-NOT-A-REAL-KEY-0000' });
  assert.equal(status.total, 4);
  assert.equal(status.setCount, 1);
  const openai = status.keys.find((k) => k.id === 'openai');
  assert.equal(openai.set, true);
  assert.equal(JSON.stringify(status).includes('sk-test'), false);
});

test('validateKeySetupUpdates accepts null remove and rejects unknown', () => {
  assert.equal(validateKeySetupUpdates({ OPENAI_API_KEY: null }).ok, true);
  assert.equal(validateKeySetupUpdates({ NOT_A_KEY: 'x' }).ok, false);
  assert.equal(validateKeySetupUpdates({ OPENAI_API_KEY: 'has space' }).ok, false);
});

test('upsertDotenvValues appends and removes', () => {
  const once = upsertDotenvValues('', { OPENAI_API_KEY: 'sk-test-NOT-A-REAL-KEY-0000' });
  assert.match(once, /^OPENAI_API_KEY=sk-test-NOT-A-REAL-KEY-0000$/m);
  const gone = upsertDotenvValues(once, { OPENAI_API_KEY: null });
  assert.match(gone, /^# OPENAI_API_KEY=$/m);
});

test('admitKeySetupRequest refuses proxy and sharing; allows loopback', () => {
  const base = {
    method: 'GET',
    remoteAddress: '127.0.0.1',
    hostHeader: '127.0.0.1:8787',
    protocol: 'http:',
    env: { PINOKIO_SHARE_VAR: '__cockpit_sharing_disabled__' },
  };
  assert.equal(admitKeySetupRequest(base).ok, true);
  assert.equal(
    admitKeySetupRequest({ ...base, proxyHeaders: { 'x-forwarded-for': '1.1.1.1' } }).ok,
    false,
  );
  assert.equal(
    admitKeySetupRequest({
      ...base,
      env: { PINOKIO_SHARE_CLOUDFLARE: 'true', PINOKIO_SHARE_VAR: '__cockpit_sharing_disabled__' },
    }).ok,
    false,
  );
  assert.equal(admitKeySetupRequest({ ...base, remoteAddress: '8.8.8.8' }).ok, false);
});

test('isKeySetupExternallyManaged', () => {
  assert.equal(
    isKeySetupExternallyManaged({ effectiveValue: 'a', storedValue: 'a', wasExternalAtBoot: true }),
    true,
  );
  assert.equal(
    isKeySetupExternallyManaged({ effectiveValue: 'a', storedValue: 'a', wasExternalAtBoot: false }),
    false,
  );
});
