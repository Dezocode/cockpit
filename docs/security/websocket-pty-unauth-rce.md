# Vulnerability: unauthenticated RCE via /ws/pty

Issue: https://github.com/Dezocode/cockpit/issues/16 — **CRITICAL**

## Problem

The WebSocket PTY endpoint `wss://<host>/ws/pty` spawns an interactive
shell with **no authentication, no token check, and no origin
validation**, and the repo's own supported deploy path
(`scripts/install-hostinger.sh` → nginx + systemd) exposes it to the
public internet.

## Evidence

- `app/server/index.ts:172-207` — `new WebSocketServer({ server:
  nodeServer, path: "/ws/pty" })`; on `connection` it immediately runs
  `nodePty.spawn(process.env.SHELL || "bash", ["-l"], ...)` as the
  service user. No auth anywhere in the handler.
- `app/server/index.ts:199` — `pty.write(msg.data)` executes arbitrary
  attacker-supplied shell input from `{"type":"input","data":"..."}`
  messages.
- `app/server/index.ts:64` — `app.use("/*", cors())` (wide-open CORS);
  `app/server/index.ts:209` — `nodeServer.listen(port)` with no host
  (binds 0.0.0.0).
- `packaging/nginx/cockpit.conf` (`location /ws/` → `proxy_pass
  http://cockpit_web`) — installed to `/etc/nginx/sites-enabled/` by
  `scripts/install-hostinger.sh`; same exposure in legacy
  `deploy/nginx-cockpit.conf`.
- `packaging/systemd/cockpit-web.service` — runs as `User=cockpit`.
- Frontend consumes this endpoint (`app/src/lib/api.ts:50`,
  `ptyWebSocketUrl()`), confirming it ships as the browser-terminal
  feature — with no access control.

## Impact

- Any internet client gets a full interactive shell as the `cockpit`
  systemd user on the Hostinger VPS (owns `/opt/cockpit`).
- That user holds the operator's GitHub OAuth token: `POST
  /api/auth/gh/device/poll` runs `gh auth login --with-token`
  server-side (scopes `repo,gist,read:org`), so host compromise also
  yields repo-scoped GitHub credentials.
- Wide-open CORS means a malicious web page can drive the victim's
  browser straight into the terminal.

## Recommended fix

1. Require authentication on `/ws/pty` (verify a signed session token
   issued at login before upgrading/spawning the pty).
2. Bind the Node server to `127.0.0.1` so only nginx (or local
   clients) can reach it.
3. Until auth lands, restrict the nginx `location /ws/` block (IP
   allowlist or basic auth).

## Steering prompt (agent-executable)

> In Dezocode/cockpit, fix the critical unauthenticated RCE in
> `/ws/pty` per https://github.com/Dezocode/cockpit/issues/16. (1)
> Gate the WebSocket upgrade in `app/server/index.ts:172-207` on a
> signed session token (issue it at login, verify before
> `nodePty.spawn`). (2) Bind the Node server to `127.0.0.1` instead of
> 0.0.0.0 (`index.ts:209`). (3) Tighten CORS (`index.ts:64`) to the
> app's own origin. (4) Until auth lands, add IP-allowlist/basic-auth
> to the nginx `location /ws/` block in
> `packaging/nginx/cockpit.conf` AND legacy `deploy/nginx-cockpit.conf`.
> (5) Add a regression test: an unauthenticated websocket client to
> `/ws/pty` must be rejected before any pty spawn. Do not break the
> legitimate browser-terminal feature (`app/src/lib/api.ts:50`).
> Open a PR; do not merge it yourself.
