#!/usr/bin/env node
// Cockpit-authored CLI over ported keySetupCore + hardening (no provenance header — not a port).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { parseEnv } from 'node:util';
import { createInterface } from 'node:readline';
import {
  KEY_SETUP_KEYS,
  knownKeySetupEnvVars,
  keySetupStatus,
  upsertDotenvValues,
  validateKeySetupUpdates,
} from './keySetupCore.mjs';
import { hardenCredentialFile } from './keySetupHardening.mjs';
import { projectRoot } from './projectRoot.mjs';
import { randomUUID } from 'node:crypto';

const ROOT = projectRoot(import.meta.url);

function storePath() {
  if (process.env.COCKPIT_LAUNCHER === 'pinokio') {
    return path.join(ROOT, 'pinokio', 'ENVIRONMENT');
  }
  const xdg = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
  return path.join(xdg, 'cockpit', 'keys.env');
}

function ensureDir(filepath) {
  const dir = path.dirname(filepath);
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  try { fs.chmodSync(dir, 0o700); } catch { /* */ }
}

function readStore() {
  try {
    return fs.readFileSync(storePath(), 'utf8');
  } catch (e) {
    if (e && e.code === 'ENOENT') return '';
    throw e;
  }
}

function persist(text) {
  const filepath = storePath();
  ensureDir(filepath);
  try {
    if (fs.lstatSync(filepath).isSymbolicLink()) throw new Error('refusing symlink store');
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
  }
  const tmp = path.join(path.dirname(filepath), `.${path.basename(filepath)}.${randomUUID().slice(0, 8)}.tmp`);
  const fd = fs.openSync(tmp, 'wx', 0o600);
  let staged = false;
  try {
    if (!hardenCredentialFile(tmp)) throw new Error('harden failed');
    const buf = Buffer.from(text, 'utf8');
    let w = 0;
    while (w < buf.length) w += fs.writeSync(fd, buf, w, buf.length - w);
    fs.fsyncSync(fd);
    staged = true;
  } finally {
    fs.closeSync(fd);
    if (!staged) fs.rmSync(tmp, { force: true });
  }
  fs.renameSync(tmp, filepath);
  try { fs.chmodSync(filepath, 0o600); } catch { /* */ }
}

function loadEffectiveEnv() {
  const fromStore = parseEnv(readStore() || '');
  return { ...fromStore, ...process.env };
}

function findEntry(id) {
  return KEY_SETUP_KEYS.find((e) => e.id === id || e.envVars.includes(id));
}

async function readSecret(id) {
  if (!process.stdin.isTTY) {
    const chunks = [];
    for await (const c of process.stdin) chunks.push(c);
    return Buffer.concat(chunks).toString('utf8').trim();
  }
  process.stderr.write(`Enter value for ${id} (input hidden): `);
  // No-echo TTY read via stty when available
  const stty = spawnSync('stty', ['-echo'], { stdio: 'inherit' });
  try {
    const rl = createInterface({ input: process.stdin, output: process.stderr });
    const value = await new Promise((resolve) => rl.question('', resolve));
    rl.close();
    process.stderr.write('\n');
    return String(value || '').trim();
  } finally {
    if (stty.status === 0) spawnSync('stty', ['echo'], { stdio: 'inherit' });
  }
}

function usage() {
  console.log(`Usage:
  cockpit keys list [--json]
  cockpit keys set <id>          # value from stdin or no-echo TTY
  cockpit keys unset <id>
  cockpit keys exec --for <provider> -- <cmd> [args...]

Ids: ${KEY_SETUP_KEYS.map((e) => e.id).join(', ')}`);
}

async function main(argv) {
  const args = argv.slice(2);
  const cmd = args[0];
  if (!cmd || cmd === '-h' || cmd === '--help') { usage(); return 0; }

  if (cmd === 'list') {
    const env = loadEffectiveEnv();
    const status = keySetupStatus(env);
    if (args.includes('--json')) {
      console.log(JSON.stringify(status, null, 2));
    } else {
      for (const k of status.keys) {
        console.log(`${k.set ? 'set ✓' : 'not set'}  ${k.id}  ${k.title}`);
      }
      console.log(`${status.setCount}/${status.total} set`);
    }
    return 0;
  }

  if (cmd === 'set') {
    const id = args[1];
    const entry = findEntry(id);
    if (!entry) { console.error(`unknown id: ${id}`); return 2; }
    const value = await readSecret(entry.id);
    const body = {};
    for (const envVar of entry.envVars) body[envVar] = value;
    const verdict = validateKeySetupUpdates(body);
    if (!verdict.ok) { console.error(verdict.error); return 2; }
    persist(upsertDotenvValues(readStore(), verdict.updates));
    for (const [n, v] of Object.entries(verdict.updates)) process.env[n] = v;
    console.log(`set ${entry.id}`);
    return 0;
  }

  if (cmd === 'unset') {
    const id = args[1];
    const entry = findEntry(id);
    if (!entry) { console.error(`unknown id: ${id}`); return 2; }
    const body = {};
    for (const envVar of entry.envVars) body[envVar] = null;
    const verdict = validateKeySetupUpdates(body);
    if (!verdict.ok) { console.error(verdict.error); return 2; }
    persist(upsertDotenvValues(readStore(), verdict.updates));
    for (const n of Object.keys(verdict.updates)) process.env[n] = '';
    console.log(`unset ${entry.id}`);
    return 0;
  }

  if (cmd === 'exec') {
    const forIdx = args.indexOf('--for');
    const dd = args.indexOf('--');
    if (forIdx < 0 || dd < 0 || forIdx + 1 >= dd) { usage(); return 2; }
    const provider = args[forIdx + 1];
    const cmdArgs = args.slice(dd + 1);
    if (!cmdArgs.length) { usage(); return 2; }
    const env = { ...process.env, ...parseEnv(readStore() || '') };
    const inject = {};
    for (const entry of KEY_SETUP_KEYS) {
      if ((entry.providers || []).includes(provider)) {
        for (const name of entry.envVars) {
          if (env[name]) inject[name] = env[name];
        }
      }
    }
    const r = spawnSync(cmdArgs[0], cmdArgs.slice(1), {
      env: { ...process.env, ...inject },
      stdio: 'inherit',
    });
    return r.status ?? 1;
  }

  usage();
  return 2;
}

main(process.argv).then((code) => { process.exitCode = code; }).catch((e) => {
  console.error(e.message || e);
  process.exitCode = 1;
});
