#!/usr/bin/env node
// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe scripts/setup-doctor.mjs — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Node 22 floor, tmux/bash/git/watch checks, KEY_SETUP_KEYS credentials, Cockpit JSON contract.
import { existsSync, readFileSync, accessSync, constants as fsConstants } from 'node:fs';
import { spawnSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import { parseEnv } from 'node:util';
import { fileURLToPath } from 'node:url';
import { projectRoot } from './projectRoot.mjs';
import { KEY_SETUP_KEYS } from './keySetupCore.mjs';

const ROOT = projectRoot(import.meta.url);

/** Credential specs derived from KEY_SETUP_KEYS (presence only; Keychain no -w). */
export const CREDENTIALS = Object.freeze(
  KEY_SETUP_KEYS.flatMap((entry) =>
    entry.envVars.map((name) => ({
      name,
      label: entry.title,
      id: entry.id,
      hidden: Boolean(entry.hidden),
      keychain: entry.id === 'openai'
        ? [['cockpit', 'openai'], ['openai-api', 'api-key']]
        : entry.id === 'anthropic'
          ? [['cockpit', 'anthropic']]
          : entry.id === 'xai'
            ? [['cockpit', 'xai']]
            : [],
    })),
  ),
);

export function isConfiguredValue(value) {
  const normalized = String(value || '').trim();
  return normalized.length > 0 && !/^(your_|replace_|example|changeme)/i.test(normalized);
}

export function classifyNodeVersion(version = process.versions.node) {
  const [major = 0] = String(version).split('.').map(Number);
  if (major === 22 || major === 24 || major === 26) {
    return { level: 'ok', summary: `supported (Node ${major})` };
  }
  if (major < 22) {
    return { level: 'error', summary: 'too old; install Node 22 or newer' };
  }
  return { level: 'warn', summary: 'newer than this release has verified; Node 22/24/26 is the tested path' };
}

export function hasRequiredDependencies(rootDir = ROOT) {
  const appPkg = path.join(rootDir, 'app', 'package.json');
  const appNm = path.join(rootDir, 'app', 'node_modules');
  if (!existsSync(appPkg)) return false;
  try {
    const manifest = JSON.parse(readFileSync(appPkg, 'utf8'));
    const packages = new Set([
      ...Object.keys(manifest.dependencies || {}),
      ...Object.keys(manifest.devDependencies || {}),
    ]);
    if (packages.size === 0) return existsSync(appNm);
    // Spot-check a few critical deps rather than every transitive name.
    const critical = ['hono', 'react', 'vite'].filter((n) => packages.has(n));
    return critical.every((name) =>
      existsSync(path.join(appNm, ...name.split('/'), 'package.json')),
    );
  } catch {
    return false;
  }
}

export function npmProcessSpec(platform = process.platform) {
  // Cockpit uses corepack pnpm; keep a process-spec helper for callers.
  const windows = platform === 'win32';
  return { command: windows ? 'pnpm.cmd' : 'pnpm', shell: windows, via: 'corepack pnpm' };
}

export function readDoctorDotenvValue(variableName, rootDir = ROOT) {
  const key = String(variableName || '').trim();
  if (!/^[A-Z_][A-Z0-9_]*$/i.test(key)) return '';
  const candidates = [
    path.join(rootDir, 'pinokio', 'ENVIRONMENT'),
    path.join(process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config'), 'cockpit', 'keys.env'),
    path.join(rootDir, '.env'),
  ];
  for (const filepath of candidates) {
    if (!existsSync(filepath)) continue;
    try {
      const values = parseEnv(readFileSync(filepath, 'utf8'));
      if (isConfiguredValue(values[key])) return String(values[key]);
    } catch {
      /* ignore */
    }
  }
  return '';
}

function hasKeychainItem(service, account) {
  if (process.platform !== 'darwin') return false;
  const result = spawnSync('security', ['find-generic-password', '-s', service, '-a', account], { stdio: 'ignore' });
  return result.status === 0;
}

export function resolveCredential(spec, {
  includeKeychain = true,
  authoritativeEnvironment = false,
  environment = process.env,
  rootDir = ROOT,
  keychainLookup = hasKeychainItem,
} = {}) {
  const environmentDefinesKey = Object.prototype.hasOwnProperty.call(environment, spec.name);
  if (isConfiguredValue(environment[spec.name])) return { configured: true, source: 'environment' };
  if (authoritativeEnvironment && environmentDefinesKey) return { configured: false, source: null };
  if (isConfiguredValue(readDoctorDotenvValue(spec.name, rootDir))) return { configured: true, source: 'dotenv files' };
  if (includeKeychain && (spec.keychain || []).some(([service, account]) => keychainLookup(service, account))) {
    return { configured: true, source: 'macOS Keychain' };
  }
  return { configured: false, source: null };
}

function which(cmd) {
  const hide = new Set(String(process.env.COCKPIT_DOCTOR_HIDE || '').split(',').map((s) => s.trim()).filter(Boolean));
  if (hide.has(cmd)) return '';
  const r = spawnSync('bash', ['-lc', `command -v ${cmd}`], { encoding: 'utf8' });
  return r.status === 0 ? String(r.stdout || '').trim() : '';
}

function bashMajor() {
  const r = spawnSync('bash', ['-c', 'echo "${BASH_VERSINFO[0]}"'], { encoding: 'utf8' });
  return Number(String(r.stdout || '').trim()) || 0;
}

function cockpitVersion(rootDir = ROOT) {
  try {
    const pkg = JSON.parse(readFileSync(path.join(rootDir, 'app', 'package.json'), 'utf8'));
    return String(pkg.version || '0.0.0');
  } catch {
    return '0.0.0';
  }
}

export function buildCapabilitySummary(credentials) {
  const configured = (name) => credentials[name]?.configured === true;
  const providers = [];
  if (configured('OPENAI_API_KEY')) providers.push('codex');
  if (configured('ANTHROPIC_API_KEY')) providers.push('anthropic');
  if (configured('XAI_API_KEY')) providers.push('grok');
  return {
    providers: providers.length ? providers.join(', ') : 'keyless (local agents only)',
    notify: configured('COCKPIT_NOTIFY_KEY') || configured('COCKPIT_TELEGRAM_BOT_TOKEN') || configured('COCKPIT_NTFY_TOPIC')
      ? 'configured'
      : 'optional — add keys to enable sinks',
    laya: which('python3') ? 'python present (laya optional)' : 'python missing (laya skipped)',
  };
}

function pushCheck(checks, { id, level, status, detail, fix = '' }) {
  checks.push({ id, level, status, detail, fix });
}

export function inspectSetup({ includeKeychain = true, authoritativeEnvironment = false, rootDir = ROOT } = {}) {
  const checks = [];
  const node = classifyNodeVersion();
  pushCheck(checks, {
    id: 'node',
    level: 'required',
    status: node.level === 'error' ? 'fail' : node.level === 'warn' ? 'warn' : 'ok',
    detail: `Node ${process.versions.node}: ${node.summary}`,
    fix: node.level === 'error' ? 'Install Node 22+ (https://nodejs.org) or use nvm/fnm' : '',
  });

  const bm = bashMajor();
  pushCheck(checks, {
    id: 'bash',
    level: 'required',
    status: bm >= 4 ? 'ok' : 'fail',
    detail: bm >= 4 ? `bash ${bm}` : `bash ${bm || '?'} (need ≥4)`,
    fix: bm >= 4 ? '' : 'Install bash 4+ (macOS: brew install bash; Linux: package manager)',
  });

  const tmux = which('tmux');
  pushCheck(checks, {
    id: 'tmux',
    level: 'required',
    status: tmux ? 'ok' : 'fail',
    detail: tmux || 'tmux not found',
    fix: tmux ? '' : 'Install tmux (brew install tmux / apt install tmux)',
  });

  const git = which('git');
  pushCheck(checks, {
    id: 'git',
    level: 'required',
    status: git ? 'ok' : 'fail',
    detail: git || 'git not found',
    fix: git ? '' : 'Install git',
  });

  const watch = which('inotifywait') || which('fswatch');
  pushCheck(checks, {
    id: 'watch',
    level: 'required',
    status: watch ? 'ok' : 'fail',
    detail: watch || 'no inotifywait/fswatch',
    fix: watch ? '' : 'Install inotify-tools (Linux) or fswatch (macOS: brew install fswatch)',
  });

  const cockpitBin = which('cockpit') || (existsSync(path.join(rootDir, 'bin', 'cockpit')) ? path.join(rootDir, 'bin', 'cockpit') : '');
  pushCheck(checks, {
    id: 'cockpit',
    level: 'required',
    status: cockpitBin ? 'ok' : 'fail',
    detail: cockpitBin || 'cockpit not on PATH',
    fix: cockpitBin ? '' : 'Run: bash scripts/get-cockpit.sh --from-dir "$PWD"  (or ./install.sh)',
  });

  const deps = hasRequiredDependencies(rootDir);
  pushCheck(checks, {
    id: 'web-deps',
    level: 'recommended',
    status: deps ? 'ok' : 'warn',
    detail: deps ? 'app dependencies present' : 'app/node_modules incomplete',
    fix: deps ? '' : 'cd app && corepack enable && pnpm install',
  });

  const webBuild = existsSync(path.join(rootDir, 'app', 'dist', 'index.html'));
  pushCheck(checks, {
    id: 'web-build',
    level: 'recommended',
    status: webBuild ? 'ok' : 'warn',
    detail: webBuild ? 'app/dist present' : 'app/dist missing',
    fix: webBuild ? '' : 'cd app && pnpm build',
  });

  const gh = which('gh');
  pushCheck(checks, {
    id: 'gh',
    level: 'recommended',
    status: gh ? 'ok' : 'warn',
    detail: gh || 'gh not found',
    fix: gh ? '' : 'Install GitHub CLI (https://cli.github.com)',
  });

  const py = which('python3');
  pushCheck(checks, {
    id: 'python3',
    level: 'optional',
    status: py ? 'ok' : 'skip',
    detail: py || 'python3 not found',
    fix: '',
  });

  const credentials = Object.fromEntries(CREDENTIALS.map((spec) => [
    spec.name,
    resolveCredential(spec, { includeKeychain, authoritativeEnvironment, rootDir }),
  ]));

  for (const spec of CREDENTIALS) {
    if (spec.hidden) continue;
    const state = credentials[spec.name];
    let status = 'skip';
    let detail = 'not set (optional)';
    if (state.configured) {
      if (state.source === 'macOS Keychain') {
        status = 'warn';
        detail = 'in Keychain but not exported';
      } else {
        status = 'ok';
        detail = `set (${state.source})`;
      }
    }
    pushCheck(checks, {
      id: `key:${spec.name}`,
      level: 'optional',
      status,
      detail,
      fix: status === 'ok' ? '' : `cockpit keys set ${spec.id}   # value on stdin; never paste into chat`,
    });
  }

  const required_failed = checks.filter((c) => c.level === 'required' && c.status === 'fail').length;
  return {
    os: process.platform === 'darwin' ? 'darwin' : process.platform === 'linux' ? 'linux' : process.platform,
    arch: process.arch,
    cockpit_version: cockpitVersion(rootDir),
    checks,
    required_failed,
    ready: required_failed === 0 && node.level !== 'error',
    node: { version: process.versions.node, ...node },
    credentials,
    capabilities: buildCapabilitySummary(credentials),
    dependenciesInstalled: deps,
  };
}

export function formatSetupReport(report, { readyMessage } = {}) {
  const lines = [
    'Cockpit setup doctor',
    '',
    `OS ${report.os}/${report.arch}  version ${report.cockpit_version}`,
    '',
  ];
  for (const c of report.checks) {
    const tag = c.status === 'ok' ? 'OK' : c.status === 'warn' ? 'WARN' : c.status === 'fail' ? 'FAIL' : 'SKIP';
    lines.push(`[${tag}] ${c.id}: ${c.detail}`);
    if (c.fix) lines.push(`       fix: ${c.fix}`);
  }
  lines.push('');
  lines.push(`Providers: ${report.capabilities.providers}`);
  lines.push(`Notify:    ${report.capabilities.notify}`);
  lines.push(`Laya:      ${report.capabilities.laya}`);
  lines.push('');
  lines.push(
    report.required_failed === 0
      ? (readyMessage || 'Ready. Run cockpit or cockpit-web.')
      : 'Setup needs attention before Cockpit can start.',
  );
  return lines.join('\n');
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : '';
if (invokedPath === fileURLToPath(import.meta.url)) {
  const wantFix = process.argv.includes('--fix');
  const report = inspectSetup();
  if (process.argv.includes('--json')) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    console.log(formatSetupReport(report));
    if (wantFix) {
      for (const c of report.checks) {
        if (c.fix) console.log(c.fix);
      }
    }
  }
  if (report.required_failed > 0) process.exitCode = 1;
}
