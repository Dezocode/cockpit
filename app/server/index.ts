import { Hono, type Context } from "hono";
import { cors } from "hono/cors";
import { getRequestListener } from "@hono/node-server";
import { getConnInfo } from "@hono/node-server/conninfo";
import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync, execFile } from "node:child_process";
import { createServer } from "node:http";
import { WebSocketServer } from "ws";
import { createHmac, createHash, timingSafeEqual, randomBytes } from "node:crypto";
import { fleetNodesApp } from "./fleet/nodes.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "../..");
const fixturesDir = join(root, "fixtures");

function readJson<T>(name: string, fallback: T): T {
  const path = join(fixturesDir, name);
  if (!existsSync(path)) return fallback;
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function ghAuthStatus(): { authenticated: boolean; user?: string; host: string } {
  try {
    const out = execSync("gh auth status -h github.com 2>&1", { encoding: "utf8" });
    const user = out.match(/Logged in to github\.com account (\S+)/)?.[1];
    return { authenticated: out.includes("Logged in"), user, host: "github.com" };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const user = msg.match(/Logged in to github\.com account (\S+)/)?.[1];
    if (user) return { authenticated: true, user, host: "github.com" };
    return { authenticated: false, host: "github.com" };
  }
}

function healthCheck() {
  const gh = ghAuthStatus();
  const tui = existsSync(join(root, "bin/cockpit"));
  const fixtures = existsSync(join(fixturesDir, "agents.json"));
  const web = existsSync(join(root, "app/dist/index.html"));
  const api = existsSync(join(root, "app/dist-server/index.js"));
  const hostinger = process.env.COCKPIT_HOSTINGER === "1";
  const core = tui && fixtures;
  const hostingerReady = !hostinger || (web && api);
  return {
    status: core && hostingerReady ? "green" : "yellow",
    product: "cockpit",
    seed: "cockpit-20260907",
    checks: {
      tui: tui ? "ok" : "missing",
      fixtures: fixtures ? "ok" : "missing",
      gh_auth: gh.authenticated ? "ok" : "pending",
      web_build: web ? "ok" : "pending",
      api_server: api ? "ok" : "pending",
      hostinger: hostinger ? "configured" : "local",
    },
    source: "app/dist-server/index.js",
    gh,
    timestamp: new Date().toISOString(),
  };
}

const app = new Hono();
app.use("/*", cors());

// GitHub CLI public OAuth app (device-flow) — tokens land in gh OS keyring only, never in repo.
const GH_CLI_CLIENT_ID = "178c6fc778ccc68e1d6a";

const deviceSessions = new Map<string, { interval: number; expires: number }>();

app.get("/api/health", (c) => c.json(healthCheck())); // green contract — see deploy/README.md
app.get("/api/agents", (c) => c.json(readJson("agents.json", { agents: [], seed: "cockpit-20260907" })));
app.get("/api/layout", (c) => c.json(readJson("layout.json", { panels: [], activePanel: "AGENT" })));
app.get("/api/auth/gh", (c) => c.json(ghAuthStatus()));

app.post("/api/auth/gh/device/start", async (c) => {
  const res = await fetch("https://github.com/login/device/code", {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({ client_id: GH_CLI_CLIENT_ID, scope: "repo,gist,read:org" }),
  });
  const data = (await res.json()) as {
    device_code: string;
    user_code: string;
    verification_uri: string;
    expires_in: number;
    interval: number;
  };
  deviceSessions.set(data.device_code, {
    interval: data.interval,
    expires: Date.now() + data.expires_in * 1000,
  });
  return c.json(data);
});

app.post("/api/auth/gh/device/poll", async (c) => {
  const { device_code } = (await c.req.json()) as { device_code: string };
  const session = deviceSessions.get(device_code);
  if (!session || Date.now() > session.expires) {
    return c.json({ status: "error", message: "device code expired" });
  }
  const res = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({ client_id: GH_CLI_CLIENT_ID, device_code, grant_type: "urn:ietf:params:oauth:grant-type:device_code" }),
  });
  const data = (await res.json()) as { access_token?: string; error?: string; interval?: number };
  if (data.access_token) {
    try {
      execSync("gh auth login --with-token", {
        input: data.access_token,
        encoding: "utf8",
        stdio: ["pipe", "pipe", "pipe"],
      });
    } catch {
      /* gh stores in OS keyring when available */
    }
    deviceSessions.delete(device_code);
    const gh = ghAuthStatus();
    return c.json({ status: "complete", authenticated: gh.authenticated, user: gh.user });
  }
  if (data.error === "authorization_pending") {
    return c.json({ status: "pending" });
  }
  return c.json({ status: "error", message: data.error ?? "poll failed" });
});

app.get("/api/emulators", (c) =>
  c.json({
    registry: [
      { id: "foot", label: "Foot", sizeOwning: true, shellOut: true, dezohostSocket: true },
      { id: "ghostty", label: "Ghostty", sizeOwning: false, shellOut: true, dezohostSocket: false },
    ],
    funnel: "OFF",
    serve: "OFF",
  }),
);

app.post("/api/emulators/:id/launch", (c) => {
  const id = c.req.param("id");
  const cmd = id === "foot" ? "foot" : id === "ghostty" ? "ghostty" : null;
  if (!cmd) return c.json({ ok: false, message: "unknown emulator" }, 404);
  return c.json({
    ok: true,
    message: `Shell-out ${cmd} via dezohost product socket (Foot size-owning). Not embedded in xterm.`,
  });
});

app.route("/", fleetNodesApp);

app.get("/api/memory", (c) =>
  c.json({
    entries: [
      { id: "mem-1", title: "Agent profile sync", source: "cockpit.memory", ts: "2026-09-07T05:00:00Z" },
      { id: "mem-2", title: "Intercom fail-closed guard", source: "cockpit.intercom", ts: "2026-09-07T05:01:00Z" },
    ],
    failClosed: true,
  }),
);

// --- cockpit#16: GitHub-OAuth-tied terminal auth (no pre-shared tokens) ---
const GH_CLIENT_ID = process.env.GITHUB_CLIENT_ID ?? "";
const GH_CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET ?? "";
const GH_REDIRECT_URI = process.env.GITHUB_REDIRECT_URI ?? "";
const SESSION_SECRET = process.env.COCKPIT_SESSION_SECRET ?? "";
const TERMINAL_USERS = new Set(
  (process.env.COCKPIT_TERMINAL_USERS ?? "").split(",").map((x) => x.trim().toLowerCase()).filter(Boolean),
);
const TERMINAL_TEAMS = new Set(
  (process.env.COCKPIT_TERMINAL_TEAMS ?? "").split(",").map((x) => x.trim().toLowerCase()).filter(Boolean),
);
const oauthConfigured = Boolean(GH_CLIENT_ID && GH_CLIENT_SECRET && GH_REDIRECT_URI && SESSION_SECRET);
if (!oauthConfigured) {
  console.error("[auth] GitHub OAuth / session secret not configured — /ws/pty will reject all connections");
}
function b64url(buf: Buffer): string {
  return buf.toString("base64url");
}
function signSession(payload: string): string {
  const sig = createHmac("sha256", SESSION_SECRET).update(payload).digest();
  return `${b64url(Buffer.from(payload))}.${b64url(sig)}`;
}
interface TerminalSession { u: string; teams: string[]; did: string; exp: number }
function verifySession(token: string): TerminalSession | null {
  try {
    const parts = token.split(".");
    const p = parts[0]; const sg = parts[1];
    if (!p || !sg) return null;
    const expect = createHmac("sha256", SESSION_SECRET).update(Buffer.from(p, "base64url")).digest();
    const got = Buffer.from(sg, "base64url");
    if (expect.length !== got.length || !timingSafeEqual(expect, got)) return null;
    const data = JSON.parse(Buffer.from(p, "base64url").toString("utf8")) as TerminalSession;
    if (!data.u || !data.exp || Date.now() > data.exp) return null;
    return data;
  } catch { return null; }
}
function signState(ts: number): string {
  const payload = `gh-state|${ts}`;
  const sig = createHmac("sha256", SESSION_SECRET).update(payload).digest("hex");
  return Buffer.from(`${payload}|${sig}`).toString("base64url");
}
function verifyState(token: string, maxAgeMs = 600_000): boolean {
  try {
    const parts = Buffer.from(token, "base64url").toString("utf8").split("|");
    const ts = parts[1]; const sig = parts[2];
    const expect = createHmac("sha256", SESSION_SECRET).update(`gh-state|${ts}`).digest("hex");
    return sig === expect && Date.now() - Number(ts) < maxAgeMs;
  } catch { return false; }
}
function terminalGranted(sess: TerminalSession): boolean {
  if (TERMINAL_USERS.has(sess.u.toLowerCase())) return true;
  return sess.teams.some((t) => TERMINAL_TEAMS.has(t.toLowerCase()));
}
function readSessionCookie(c: { req: { header: (n: string) => string | undefined } }): TerminalSession | null {
  const cookie = c.req.header("cookie") ?? "";
  const m = cookie.match(/(?:^|;\s*)cockpit_sess=([^;]+)/);
  return m ? verifySession(decodeURIComponent(m[1])) : null;
}
function registerDevice(did: string, user: string, ua: string): void {
  try {
    const path = join(fixturesDir, "terminal-devices.json");
    const all = (existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : {}) as Record<string, Record<string, string>>;
    const prev = all[did] ?? { user, firstSeen: new Date().toISOString() };
    all[did] = { ...prev, user, lastSeen: new Date().toISOString(), ua: ua.slice(0, 200) };
    writeFileSync(path, JSON.stringify(all, null, 2));
  } catch { /* device registry is best-effort; auth does not depend on it */ }
}

app.get("/api/auth/github/start", (c) => {
  if (!oauthConfigured) return c.json({ error: "github oauth not configured" }, 404);
  const state = signState(Date.now());
  const params = new URLSearchParams({
    client_id: GH_CLIENT_ID, redirect_uri: GH_REDIRECT_URI,
    scope: "read:user read:org", state,
  });
  return c.redirect(`https://github.com/login/oauth/authorize?${params}`, 302);
});

app.get("/api/auth/github/callback", async (c) => {
  if (!oauthConfigured) return c.json({ error: "github oauth not configured" }, 404);
  const code = c.req.query("code"); const state = c.req.query("state");
  if (!code || !state || !verifyState(state)) return c.text("bad oauth state", 400);
  const tokRes = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({ client_id: GH_CLIENT_ID, client_secret: GH_CLIENT_SECRET, code }),
  });
  const tok = (await tokRes.json()) as { access_token?: string };
  if (!tok.access_token) return c.text("oauth exchange failed", 400);
  const gh = { Authorization: `Bearer ${tok.access_token}`, "User-Agent": "dezocode-cockpit" };
  const me = (await (await fetch("https://api.github.com/user", { headers: gh })).json()) as { login?: string };
  const teams = (await (await fetch("https://api.github.com/user/teams", { headers: gh })).json()) as
    Array<{ organization?: { login?: string }; slug?: string }>;
  const login = (me.login ?? "").toLowerCase();
  if (!login) return c.text("github user lookup failed", 400);
  const teamSlugs = teams.map((t) => `${t.organization?.login ?? ""}:${t.slug ?? ""}`.toLowerCase());
  const did = c.req.query("device") || randomBytes(12).toString("hex");
  registerDevice(did, login, c.req.header("user-agent") ?? "");
  const payload = JSON.stringify({ u: login, teams: teamSlugs, did, exp: Date.now() + 12 * 3600_000 });
  const secure = c.req.header("x-forwarded-proto") === "https" || new URL(c.req.url).protocol === "https:";
  c.header("Set-Cookie",
    `cockpit_sess=${encodeURIComponent(signSession(payload))}; Path=/; HttpOnly; SameSite=Lax; Max-Age=43200${secure ? "; Secure" : ""}`);
  return c.redirect("/", 302);
});

app.get("/api/auth/me", (c) => {
  const sess = readSessionCookie(c);
  if (!sess) return c.json({ authenticated: false });
  return c.json({ authenticated: true, login: sess.u, teams: sess.teams, terminal: terminalGranted(sess) });
});

app.post("/api/auth/logout", (c) => {
  c.header("Set-Cookie", "cockpit_sess=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0");
  return c.json({ ok: true });
});

// --- C7 (t1127u): outbound notify. ONE sender: bin/cockpit-notify via execFile. ---
// The server never talks to Telegram/ntfy itself and never echoes sink stderr.
// Gate (in order): OAuth session passing terminalGranted, Bearer COCKPIT_NOTIFY_KEY,
// COCKPIT_LOCAL_TRUST=1 + loopback socket peer (disabled outright by COCKPIT_HOSTINGER=1).
const NOTIFY_SINKS = new Set(["auto", "telegram", "ntfy", "desktop", "all"]);
const NOTIFY_PRIORITIES = new Set(["low", "default", "high"]);
const NOTIFY_RATE = { capacity: 10, refillPerMs: 10 / 60_000 }; // 10/min per principal
const notifyBuckets = new Map<string, { tokens: number; at: number }>();

function sha256(v: string): Buffer {
  return createHash("sha256").update(v).digest();
}

function notifyPrincipal(c: Context): string | null {
  const sess = readSessionCookie(c);
  if (sess && terminalGranted(sess)) return `session:${sess.u.toLowerCase()}`;
  const key = process.env.COCKPIT_NOTIFY_KEY ?? "";
  const m = (c.req.header("authorization") ?? "").match(/^Bearer\s+(\S+)$/i);
  if (key && m && timingSafeEqual(sha256(m[1]), sha256(key))) return "bearer";
  if (process.env.COCKPIT_HOSTINGER === "1" || process.env.COCKPIT_LOCAL_TRUST !== "1") return null;
  let peer = "";
  try {
    peer = getConnInfo(c).remote.address ?? ""; // socket peer, never a forwarded header
  } catch {
    return null;
  }
  return peer === "127.0.0.1" || peer === "::1" || peer === "::ffff:127.0.0.1" ? "local" : null;
}

function notifyTake(principal: string): boolean {
  const now = Date.now();
  const b = notifyBuckets.get(principal) ?? { tokens: NOTIFY_RATE.capacity, at: now };
  b.tokens = Math.min(NOTIFY_RATE.capacity, b.tokens + (now - b.at) * NOTIFY_RATE.refillPerMs);
  b.at = now;
  notifyBuckets.set(principal, b);
  if (b.tokens < 1) return false;
  b.tokens -= 1;
  return true;
}

function runNotify(args: string[]): Promise<{ code: number; stdout: string }> {
  return new Promise((resolve) => {
    execFile(
      join(root, "bin", "cockpit-notify"),
      args,
      { env: { ...process.env, COCKPIT_NOTIFY_ORIGIN: "api" }, timeout: 20_000, maxBuffer: 1024 * 1024 },
      (err, stdout) => {
        const code = err ? (typeof (err as { code?: unknown }).code === "number" ? (err as { code: number }).code : 1) : 0;
        resolve({ code, stdout: String(stdout ?? "") });
      },
    );
  });
}

function lastJson(stdout: string): Record<string, unknown> | null {
  const line = stdout.trim().split("\n").pop() ?? "";
  try {
    const v = JSON.parse(line) as unknown;
    return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

app.get("/api/notify/status", async (c) => {
  const principal = notifyPrincipal(c);
  if (!principal) return c.json({ error: "unauthorized" }, 401);
  if (!notifyTake(principal)) return c.json({ error: "rate limited" }, 429);
  const { code, stdout } = await runNotify(["--check", "--json"]);
  const st = code === 0 ? lastJson(stdout) : null;
  if (!st) return c.json({ error: "status unavailable" }, 502);
  return c.json({ telegram: st.telegram === "ready", ntfy: st.ntfy === "configured", desktop: st.desktop === "available" });
});

app.post("/api/notify", async (c) => {
  const principal = notifyPrincipal(c);
  if (!principal) return c.json({ error: "unauthorized" }, 401);
  if (!notifyTake(principal)) return c.json({ error: "rate limited" }, 429);
  let body: Record<string, unknown>;
  try {
    const raw = (await c.req.json()) as unknown;
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("not an object");
    body = raw as Record<string, unknown>;
  } catch {
    return c.json({ error: "body must be a JSON object" }, 400);
  }
  const str = (k: string): string | undefined => (typeof body[k] === "string" ? (body[k] as string) : undefined);
  for (const k of ["message", "title", "sink", "priority", "link", "id"]) {
    if (body[k] !== undefined && typeof body[k] !== "string") return c.json({ error: `${k} must be a string` }, 400);
  }
  // eslint-disable-next-line no-control-regex
  const clean = (v: string) => v.replace(/[\x00-\x09\x0b-\x1f\x7f]/g, "").trim();
  const message = clean(str("message") ?? "");
  if (message.length < 1 || message.length > 4000) return c.json({ error: "message must be 1..4000 chars" }, 400);
  const title = str("title") !== undefined ? clean(str("title") as string).replace(/\n/g, " ") : undefined;
  if (title !== undefined && title.length > 120) return c.json({ error: "title must be <= 120 chars" }, 400);
  const sink = str("sink");
  if (sink !== undefined && !NOTIFY_SINKS.has(sink)) return c.json({ error: "invalid sink" }, 400);
  const priority = str("priority");
  if (priority !== undefined && !NOTIFY_PRIORITIES.has(priority)) return c.json({ error: "invalid priority" }, 400);
  const link = str("link");
  if (link !== undefined && !/^https:\/\/[^\s\x00-\x1f\x7f]+$/.test(link)) return c.json({ error: "link must be https" }, 400);
  const id = str("id");
  if (id !== undefined && !/^[A-Za-z0-9._:-]{1,128}$/.test(id)) return c.json({ error: "invalid id" }, 400);
  const args = ["--json", "--via", "local"];
  if (title) args.push("--title", title);
  if (sink) args.push("--sink", sink);
  if (priority) args.push("--priority", priority);
  if (link) args.push("--link", link);
  if (id) args.push("--id", id);
  args.push("--", message);
  const { code, stdout } = await runNotify(args);
  const receipt = lastJson(stdout); // the CLI's receipt: secret-free by construction
  if (code === 2) return c.json({ error: "invalid request" }, 400);
  if (!receipt) return c.json({ error: "notify failed" }, 502);
  return c.json(receipt, code === 0 ? 200 : 502);
});

const port = Number(process.env.COCKPIT_WEB_PORT ?? 8787);
const nodeServer = createServer(getRequestListener(app.fetch));
const wss = new WebSocketServer({ server: nodeServer, path: "/ws/pty" });

wss.on("connection", (ws, req) => {
  // cockpit#16: every terminal session is tied to a GitHub-OAuth session.
  // Agents hold no terminal credentials of their own; they act inside the
  // owning user's session (user + agentId logged together below).
  if (!oauthConfigured) { ws.close(4401, "terminal auth not configured"); return; }
  const cookie = req.headers.cookie ?? "";
  const m = cookie.match(/(?:^|;\s*)cockpit_sess=([^;]+)/);
  const sess = m ? verifySession(decodeURIComponent(m[1])) : null;
  const ip = req.socket.remoteAddress ?? "unknown";
  if (!sess || !terminalGranted(sess)) {
    console.warn(`[pty] rejected terminal connection from ${ip}`);
    ws.close(4401, "unauthorized");
    return;
  }
  const agentId = new URL(req.url ?? "", "http://x").searchParams.get("agent") ?? "-";
  console.log(`[pty] terminal session opened for ${sess.u} (device ${sess.did.slice(0, 8)}..., agent ${agentId}) from ${ip}`);
  type PtyLike = {
    write: (d: string) => void;
    kill: () => void;
    resize: (c: number, r: number) => void;
    onData: (cb: (d: string) => void) => void;
    onExit: (cb: (e: { exitCode: number }) => void) => void;
  };
  let pty: PtyLike | null = null;
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const nodePty = require("node-pty") as { spawn: (...args: unknown[]) => PtyLike };
    pty = nodePty.spawn(process.env.SHELL || "bash", ["-l"], {
      name: "xterm-256color",
      cols: 120,
      rows: 30,
      cwd: root,
      env: process.env,
    });
    pty.onData((data) => ws.send(JSON.stringify({ type: "data", data })));
    pty.onExit(({ exitCode }) => ws.send(JSON.stringify({ type: "exit", exitCode })));
  } catch {
    ws.send(JSON.stringify({ type: "data", data: "\r\n[pty] node-pty unavailable\r\n" }));
  }

  ws.on("message", (raw) => {
    try {
      const msg = JSON.parse(String(raw)) as { type: string; data?: string; cols?: number; rows?: number };
      if (!pty) return;
      if (msg.type === "input" && msg.data) pty.write(msg.data);
      if (msg.type === "resize" && msg.cols && msg.rows) pty.resize(msg.cols, msg.rows);
    } catch {
      /* ignore */
    }
  });

  ws.on("close", () => pty?.kill());
});

const host = process.env.COCKPIT_WEB_HOST ?? "127.0.0.1";
nodeServer.listen(port, host, () => {
  console.log(`cockpit-web listening on http://${host}:${port}`);
});
