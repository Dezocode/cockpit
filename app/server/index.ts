import { Hono } from "hono";
import { cors } from "hono/cors";
import { getRequestListener } from "@hono/node-server";
import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";
import { createServer } from "node:http";
import { WebSocketServer } from "ws";

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

const port = Number(process.env.COCKPIT_WEB_PORT ?? 8787);
const nodeServer = createServer(getRequestListener(app.fetch));
const wss = new WebSocketServer({ server: nodeServer, path: "/ws/pty" });

wss.on("connection", (ws) => {
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
