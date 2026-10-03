// Ported from bilawalsidhu/gods-eye-view@b210ab0fe4d71c7faa0268134e0aa5f3c53fc7fe server/standalone/key-setup.js — MIT © 2026 Bilawal Sidhu. Modified for Cockpit: Hono /api/setup; XDG keys.env or pinokio/ENVIRONMENT; COCKPIT_LAUNCHER; session/LOCAL_TRUST gate; no server.restart.
import { Hono, type Context } from "hono";
import { getConnInfo } from "@hono/node-server/conninfo";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseEnv as parseDotenvText } from "node:util";
import { randomUUID } from "node:crypto";
import {
  knownKeySetupEnvVars,
  admitKeySetupRequest,
  isKeySetupExternallyManaged,
  keySetupStatus,
  validateKeySetupUpdates,
  upsertDotenvValues,
} from "./keySetupCore.mjs";
import { hardenCredentialFile } from "./keySetupHardening.mjs";
import { projectRoot } from "./projectRoot.mjs";
import { readEnvironmentSource as readPinokioEnvironmentSource } from "./pinokioEnvironment.mjs";

const ROOT = projectRoot(import.meta.url);
const LAUNCHER_AT_BOOT = process.env.COCKPIT_LAUNCHER;

const PROVIDER_ENV_AT_BOOT = ((globalThis as unknown as { __COCKPIT_PROVIDER_ENV_AT_BOOT?: Record<string, string> })
  .__COCKPIT_PROVIDER_ENV_AT_BOOT ??= Object.freeze(
  Object.fromEntries(
    [...knownKeySetupEnvVars()].map((name) => [name, String(process.env[name] ?? "").trim()]),
  ),
)) as Record<string, string>;

export type SessionReader = (c: Context) => { u: string; teams?: string[]; did?: string } | null;
export type TerminalGranted = (sess: { u: string; teams?: string[]; did?: string; exp?: number }) => boolean;

function pinokioManaged(): boolean {
  return LAUNCHER_AT_BOOT === "pinokio";
}

function storeName(): string {
  return pinokioManaged() ? "pinokio-environment" : "keys-env";
}

function storePath(): string {
  if (pinokioManaged()) return path.join(ROOT, "pinokio", "ENVIRONMENT");
  const xdg = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
  return path.join(xdg, "cockpit", "keys.env");
}

function ensureStoreDir(filepath: string): void {
  const dir = path.dirname(filepath);
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  try {
    fs.chmodSync(dir, 0o700);
  } catch {
    /* best-effort */
  }
}

function readStore(): string {
  try {
    if (pinokioManaged()) return readPinokioEnvironmentSource(storePath());
    return fs.readFileSync(storePath(), "utf8");
  } catch (error) {
    const err = error as NodeJS.ErrnoException;
    if (err?.code === "ENOENT") return "";
    const unreadable = new Error("the existing configuration could not be read, so nothing was changed") as Error & {
      code?: string;
    };
    unreadable.code = "COCKPIT_STORE_UNREADABLE";
    throw unreadable;
  }
}

function storeValues(): Record<string, string> {
  try {
    return parseDotenvText(readStore()) as Record<string, string>;
  } catch {
    return {};
  }
}

function isExternallyManaged(name: string, inStore: Record<string, string>): boolean {
  const wasExternalAtBoot = pinokioManaged() ? false : PROVIDER_ENV_AT_BOOT[name] !== "";
  return isKeySetupExternallyManaged({
    effectiveValue: process.env[name],
    storedValue: inStore[name],
    wasExternalAtBoot,
  });
}

function providerStatus() {
  const inStore = storeValues();
  const status = keySetupStatus(process.env);
  for (const key of status.keys) {
    (key as { managed?: string | null }).managed = key.set
      ? key.envVars.some((name: string) => isExternallyManaged(name, inStore))
        ? "external"
        : "file"
      : null;
  }
  return { ...status, store: storeName() };
}

function persistStore(text: string): void {
  const filepath = storePath();
  ensureStoreDir(filepath);
  try {
    if (fs.lstatSync(filepath).isSymbolicLink()) {
      throw new Error("refusing to write a credential store that is a symlink");
    }
  } catch (error) {
    const err = error as NodeJS.ErrnoException;
    if (err.code !== "ENOENT") throw error;
  }
  const tmp = path.join(path.dirname(filepath), `.${path.basename(filepath)}.${randomUUID().slice(0, 8)}.tmp`);
  const fd = fs.openSync(tmp, "wx", 0o600);
  let staged = false;
  try {
    if (!hardenCredentialFile(tmp)) {
      const error = new Error(
        "could not restrict the credential file to your account; nothing was saved",
      ) as Error & { code?: string };
      error.code = "COCKPIT_HARDEN_FAILED";
      throw error;
    }
    const buffer = Buffer.from(text, "utf8");
    let written = 0;
    while (written < buffer.length) {
      written += fs.writeSync(fd, buffer, written, buffer.length - written);
    }
    fs.fsyncSync(fd);
    staged = true;
  } finally {
    fs.closeSync(fd);
    if (!staged) fs.rmSync(tmp, { force: true });
  }
  try {
    fs.renameSync(tmp, filepath);
  } catch (error) {
    fs.rmSync(tmp, { force: true });
    throw error;
  }
  try {
    fs.chmodSync(filepath, 0o600);
  } catch {
    /* best-effort */
  }
}

function peerAddress(c: Context): string {
  try {
    return getConnInfo(c).remote.address ?? "";
  } catch {
    return "";
  }
}

function proxyHeadersFrom(c: Context): Record<string, string> {
  const names = [
    "forwarded",
    "via",
    "x-forwarded-for",
    "x-forwarded-host",
    "x-forwarded-port",
    "x-forwarded-proto",
    "x-real-ip",
    "cf-connecting-ip",
    "cf-ray",
  ];
  const out: Record<string, string> = {};
  for (const n of names) {
    const v = c.req.header(n);
    if (v) out[n] = v;
  }
  return out;
}

function securityHeaders(c: Context): void {
  c.header("Cache-Control", "no-store");
  c.header("X-Frame-Options", "DENY");
  c.header("Content-Security-Policy", "frame-ancestors 'none'");
}

/** Local trust: COCKPIT_LOCAL_TRUST=1 + loopback peer; disabled by HOSTINGER. */
function localTrustOk(c: Context): boolean {
  if (process.env.COCKPIT_HOSTINGER === "1") return false;
  if (process.env.COCKPIT_LOCAL_TRUST !== "1") return false;
  const peer = peerAddress(c);
  return peer === "127.0.0.1" || peer === "::1" || peer === "::ffff:127.0.0.1";
}

export function createKeySetupApp(opts: {
  readSession: SessionReader;
  terminalGranted: TerminalGranted;
}): Hono {
  const app = new Hono();

  function authorized(c: Context): boolean {
    const sess = opts.readSession(c);
    if (sess && opts.terminalGranted(sess)) return true;
    return localTrustOk(c);
  }

  function admit(c: Context, method: string) {
    const url = new URL(c.req.url);
    return admitKeySetupRequest({
      method,
      remoteAddress: peerAddress(c),
      hostHeader: c.req.header("host") ?? "",
      protocol: url.protocol,
      origin: c.req.header("origin"),
      contentType: c.req.header("content-type"),
      proxyHeaders: proxyHeadersFrom(c),
      env: process.env,
    } as Parameters<typeof admitKeySetupRequest>[0]);
  }

  app.get("/status", (c) => {
    securityHeaders(c);
    if (!authorized(c)) return c.json({ error: "unauthorized" }, 401);
    const admission = admit(c, "GET");
    if (!admission.ok) return c.json({ error: admission.error }, admission.status as 403);
    return c.json(providerStatus());
  });

  app.post("/keys", async (c) => {
    securityHeaders(c);
    if (!authorized(c)) return c.json({ error: "unauthorized" }, 401);
    const admission = admit(c, "POST");
    if (!admission.ok) return c.json({ error: admission.error }, admission.status as 403 | 415);

    let parsed: unknown;
    try {
      const raw = await c.req.text();
      if (raw.length > 8192) return c.json({ error: "Request too large" }, 413);
      parsed = JSON.parse(raw || "{}");
    } catch {
      return c.json({ error: "Invalid JSON" }, 400);
    }

    const verdict = validateKeySetupUpdates(parsed);
    if (!verdict.ok || !("updates" in verdict) || !verdict.updates) {
      return c.json({ error: (verdict as { error?: string }).error || "invalid" }, 400);
    }
    const updates = verdict.updates as Record<string, string | null>;

    const inStore = storeValues();
    for (const name of Object.keys(updates)) {
      if (isExternallyManaged(name, inStore)) {
        return c.json(
          {
            error: `${name} is configured outside Provider Settings and can only be changed where it was set`,
          },
          409,
        );
      }
    }

    try {
      persistStore(upsertDotenvValues(readStore(), updates));
    } catch (error) {
      const err = error as Error & { code?: string };
      if (err?.code === "COCKPIT_HARDEN_FAILED" || err?.code === "COCKPIT_STORE_UNREADABLE") {
        return c.json({ error: `The key was not saved: ${err.message}` }, 500);
      }
      return c.json({ error: `Could not write the ${storeName()} store` }, 500);
    }

    for (const [name, value] of Object.entries(updates)) {
      process.env[name] = value === null ? "" : value;
    }

    return c.json({
      ok: true,
      saved: Object.keys(updates),
      status: providerStatus(),
      restarting: false,
    });
  });

  return app;
}
