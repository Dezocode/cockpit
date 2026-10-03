// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe src/setupDoctor.test.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: paths + Cockpit registry/sentinel.

import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyNodeVersion, inspectSetup, formatSetupReport } from '../../app/server/gev/doctor.mjs';

test('classifyNodeVersion: 22 ok, old error', () => {
  assert.equal(classifyNodeVersion('22.11.0').level, 'ok');
  assert.equal(classifyNodeVersion('18.0.0').level, 'error');
  assert.equal(classifyNodeVersion('28.0.0').level, 'warn');
});

test('inspectSetup emits Cockpit JSON contract', () => {
  const report = inspectSetup({ includeKeychain: false });
  assert.ok(['linux', 'darwin'].includes(report.os) || typeof report.os === 'string');
  assert.ok(report.arch);
  assert.ok(Array.isArray(report.checks));
  assert.equal(typeof report.required_failed, 'number');
  for (const c of report.checks) {
    assert.ok(c.id && c.level && c.status);
    if (c.status === 'fail') assert.ok(typeof c.fix === 'string');
  }
  const text = formatSetupReport(report);
  assert.match(text, /Cockpit setup doctor/);
  assert.equal(/dezohost/.test(text), false);
});
