#!/usr/bin/env node
/**
 * Minimal Hostinger health server — GET /api/health green contract.
 * Full API: app/dist-server/index.js (systemd ExecStart).
 * Install root: /opt/cockpit — NOT /root/.grok or saul-go.
 * Envelope: frontier_subscription · Funnel OFF · no secrets bake.
 */
const http = require("node:http");
const { existsSync } = require("node:fs");
const { join } = require("node:path");

const port = Number(process.env.COCKPIT_WEB_PORT || 8787);
const root = process.env.COCKPIT_INSTALL_ROOT || "/opt/cockpit";
const hostinger = process.env.COCKPIT_HOSTINGER === "1";

function healthPayload() {
  const tui = existsSync(join(root, "bin/cockpit"));
  const web = existsSync(join(root, "app/dist/index.html"));
  const api = existsSync(join(root, "app/dist-server/index.js"));
  const core = tui || hostinger;
  const hostingerReady = !hostinger || (web && api);
  return {
    status: core && hostingerReady ? "green" : "yellow",
    product: "cockpit",
    seed: "cockpit-20260907",
    checks: {
      tui: tui ? "ok" : "missing",
      web_build: web ? "ok" : "pending",
      api_server: api ? "ok" : "pending",
      hostinger: hostinger ? "configured" : "local",
    },
    source: "packaging/health-server.js",
    timestamp: new Date().toISOString(),
  };
}

const server = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/api/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(healthPayload()));
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(port, "127.0.0.1", () => {
  process.stderr.write(`health-server listening on 127.0.0.1:${port}\n`);
});
