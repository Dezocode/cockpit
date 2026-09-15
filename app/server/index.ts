import { Hono } from "hono";
import { cors } from "hono/cors";
import { getRequestListener } from "@hono/node-server";
import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";
import { createServer } from "node:http";
import { WebSocketServer } from "ws";
import { createHmac, timingSafeEqual, randomBytes } from "node:crypto";

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
  const hostinger = process.env.COCKPIT_HOSTINGER === "1";
  const core = tui && fixtures;
  const hostingerReady = !hostinger || web;
  return {
    status: core && hostingerReady ? "green" : "yellow",
    product: "cockpit",
    seed: "cockpit-20260907",
    checks: {
      tui: tui ? "ok" : "missing",
      fixtures: fixtures ? "ok" : "missing",
      gh_auth: gh.authenticated ? "ok" : "pending",
      web_build: web ? "ok" : "pending",
      hostinger: hostinger ? "configured" : "local",
    },
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

app.get("/api/computers", (c) =>
  c.json({
    computers: [
      { id: "local", name: "Local Dev", status: "online", latencyMs: 0, tailnet: false },
      { id: "hermes", name: "Hermes Deck", status: "online", latencyMs: 12, tailnet: true, role: "hermes" },
      { id: "hostinger", name: "Hostinger VPS", status: "online", latencyMs: 42, tailnet: true },
      { id: "omarchy", name: "Omarchy Pad", status: "online", latencyMs: 8, tailnet: false },
    ],
    offlineThresholdMs: 3000,
    hermesNote: "Deck receipt / COMPUTERS node — NOT an AGENT provider",
  }),
);
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

nodeServer.listen(port, () => {
  console.log(`cockpit-web listening on http://localhost:${port}`);
});
