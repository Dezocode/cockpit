# Hostinger deploy (Canon parallel lane)

Install root: **`/opt/cockpit`** — separate from Saul `/root/.grok` and `saul-go`.

## One-liners (v2.1.4+)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.4/scripts/hostinger-grok-build.sh | sudo bash
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.4/scripts/install-hostinger.sh | sudo bash
```

Canon draft alignment: `tmp/t847u/README.md`

## Packaging layout

| Path | Purpose |
|------|---------|
| `packaging/systemd/cockpit-web.service` | systemd unit + heal pre-start |
| `packaging/systemd/cockpit-web-heal.sh` | artifact/port heal |
| `packaging/nginx/cockpit.conf` | TLS + `/api/health` proxy |
| `scripts/install-hostinger.sh` | full Hostinger install |
| `deploy/hostinger-grok-build-install.sh` | grok-build subscription recipe (canonical) |
| `scripts/hostinger-grok-build.sh` | thin wrapper → deploy recipe |
| `packaging/health-server.js` | optional GET `/api/health` bootstrap (NOT full API — see H0-HEALTH-CONTRACT.md) |
| `scripts/start-dist-server.sh` | local/systemd-equivalent dist-server start |
| `scripts/hostinger-health.sh` | GET `/api/health` probe |
| `bench/cockpit/H0-HEALTH-CONTRACT.md` | bootstrap vs full API contract |

## Health

```bash
./scripts/hostinger-health.sh
# or
curl -s http://127.0.0.1:8787/api/health | jq .
```

After certbot: `curl -s https://cockpit.example.com/api/health`
