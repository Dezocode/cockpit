# Hostinger deploy (Canon lane)

Install root: **`/opt/cockpit`** — separate from Saul `/root/.grok` and `saul-go`.

## Canonical install (single script)

```bash
./scripts/install-hostinger.sh
```

Curl one-liner (same recipe; tag-pinned v2.2.x URLs keep working on their tags):

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.2.1/scripts/install-hostinger.sh | sudo bash
```

Deploy semantics in `scripts/install-hostinger.sh`:

- **rsync:** `-a --delete` (mirror tree under `/opt/cockpit`)
- **systemd:** `packaging/systemd/cockpit-web.service` → `systemctl restart cockpit-web.service`
- **nginx:** `packaging/nginx/cockpit.conf`

Envelope: **frontier_subscription** only — DENY local Qwen/sol-v1.7.1, Funnel OFF, no secrets bake.

User-level helpers still come from `./install.sh` (without a Hostinger block — deploy steps run once in the install script above).

## Packaging on disk

| Path | Purpose |
|------|---------|
| `scripts/install-hostinger.sh` | canonical Hostinger deploy |
| `scripts/hostinger-health.sh` | GET `/api/health` probe (`--wait`) |
| `packaging/systemd/cockpit-web.service` | systemd + heal pre-start |
| `packaging/nginx/cockpit.conf` | TLS + `/api/health` proxy |

## GET /api/health

Probe after install:

```bash
curl -s http://127.0.0.1:8787/api/health | jq .
# or
./scripts/hostinger-health.sh --wait 30
```

After certbot:

```bash
curl -sf https://cockpit.example.com/api/health | jq .
```

**Green contract** (Hostinger — full API via `app/dist-server/index.js`):

```json
{
  "status": "green",
  "product": "cockpit",
  "seed": "cockpit-20260907",
  "source": "app/dist-server/index.js",
  "checks": {
    "tui": "ok",
    "fixtures": "ok",
    "api_server": "ok",
    "web_build": "ok",
    "hostinger": "configured"
  }
}
```

- `status` must be `"green"` for done-line pass
- `source` must be `"app/dist-server/index.js"` — bootstrap `packaging/health-server.js` is **not** full API PASS
- `checks.hostinger` is `"configured"` when `COCKPIT_HOSTINGER=1`
- Contract: `bench/cockpit/H0-HEALTH-CONTRACT.md`
- Implemented in `app/server/index.ts` (`GET /api/health`) → compiled `app/dist-server/index.js`

## Web terminal auth

The browser terminal (`/ws/pty`) is gated behind GitHub sign-in — no shared
tokens. Setup, env vars, and verification:
[docs/terminal-auth.md](../docs/terminal-auth.md).

Fail-closed: without the OAuth env vars, every terminal connection is refused
(close 4401). The API and health checks are unaffected.
