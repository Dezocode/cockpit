# Hostinger deploy (Canon lane)

Install root: **`/opt/cockpit`** — separate from Saul `/root/.grok` and `saul-go`.

## Grok-build subscription lane (gospel recipe)

```bash
./deploy/hostinger-grok-build-install.sh
```

Curl one-liner (same recipe via gospel path name):

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/deploy/hostinger-grok-build-install.sh | sudo bash
# or
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/scripts/hostinger-grok-build.sh | sudo bash
```

Envelope: **frontier_subscription** only — DENY local Qwen/sol-v1.7.1, Funnel OFF, no secrets bake.

## Install without grok auth step

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/scripts/install-hostinger.sh | sudo bash
```

Or via `install.sh`:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/install.sh | COCKPIT_INSTALL_HOSTINGER=1 COCKPIT_INSTALL_WEB_BUILD=1 sudo bash
```

## Packaging on disk

| Path | Purpose |
|------|---------|
| `deploy/hostinger-grok-build-install.sh` | grok-build subscription recipe (canonical) |
| `deploy/cockpit-web.service` | legacy stub → `packaging/systemd/` |
| `deploy/nginx-cockpit.conf` | legacy stub → `packaging/nginx/` |
| `packaging/systemd/cockpit-web.service` | systemd + heal pre-start |
| `packaging/nginx/cockpit.conf` | TLS + `/api/health` proxy |

## GET /api/health

Probe after install:

```bash
curl -s http://127.0.0.1:8787/api/health | jq .
# or
./scripts/hostinger-health.sh
```

After certbot:

```bash
curl -sf https://cockpit.example.com/api/health | jq .
```

**Green contract** (Hostinger):

```json
{
  "status": "green",
  "product": "cockpit",
  "seed": "cockpit-20260907",
  "checks": {
    "tui": "ok",
    "fixtures": "ok",
    "gh_auth": "ok",
    "web_build": "ok",
    "hostinger": "configured"
  }
}
```

- `status` must be `"green"` for done-line pass
- `checks.hostinger` is `"configured"` when `COCKPIT_HOSTINGER=1`
- Implemented in `app/server/index.ts` (`GET /api/health`)
