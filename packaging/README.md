# Hostinger deploy (Canon parallel lane)

Install root: **`/opt/cockpit`** — separate from Saul `/root/.grok` and `saul-go`.

## One-liners (v2.1.1+)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/scripts/hostinger-grok-build.sh | sudo bash
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.2/scripts/install-hostinger.sh | sudo bash
```

## Packaging layout

| Path | Purpose |
|------|---------|
| `packaging/systemd/cockpit-web.service` | systemd unit + heal pre-start |
| `packaging/systemd/cockpit-web-heal.sh` | artifact/port heal |
| `packaging/nginx/cockpit.conf` | TLS + `/api/health` proxy |
| `scripts/install-hostinger.sh` | full Hostinger install |
| `scripts/hostinger-grok-build.sh` | grok-build subscription lane |
| `scripts/hostinger-health.sh` | GET `/api/health` probe |

## Health

```bash
./scripts/hostinger-health.sh
# or
curl -s http://127.0.0.1:8787/api/health | jq .
```

After certbot: `curl -s https://cockpit.example.com/api/health`
