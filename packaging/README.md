# Hostinger deploy (Canon parallel lane)

Install root: **`/opt/cockpit`** — separate from Saul `/root/.grok` and `saul-go`.

## Install (canonical, v2.3.0+)

```bash
sudo ./scripts/install-hostinger.sh
./scripts/hostinger-health.sh --wait 30
```

Historical tag-pinned one-liners (they only work on the **v2.1.4** tag;
the grok-build wrapper was removed in v2.3.0 — use
`scripts/install-hostinger.sh` above):

```bash
# v2.1.4 tag only
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.4/scripts/hostinger-grok-build.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.4/scripts/install-hostinger.sh | sudo bash
```

Canon draft alignment: `tmp/t847u/README.md`

## Packaging layout

| Path | Purpose |
|------|---------|
| `packaging/systemd/cockpit-web.service` | systemd unit + heal pre-start |
| `packaging/systemd/cockpit-web-heal.sh` | artifact/port heal: stops a listener on `COCKPIT_WEB_PORT` only when it is `cockpit-web` or `node …/app/dist-server/index.js` under the install root; any other holder is named (pid + command line) and the unit does not start (`tests/test-heal-port.sh`) |
| `packaging/nginx/cockpit.conf` | TLS + `/api/health` proxy |
| `scripts/install-hostinger.sh` | canonical Hostinger install (single deploy path) |
| `packaging/health-server.js` | optional GET `/api/health` bootstrap (NOT full API — see H0-HEALTH-CONTRACT.md) |
| `scripts/start-dist-server.sh` | local dist-server start (`COCKPIT_HOSTINGER=1` in front = systemd-equivalent; see `docs/service-env.md`) |
| `scripts/hostinger-health.sh` | GET `/api/health` probe (`--wait N`) |
| `bench/cockpit/H0-HEALTH-CONTRACT.md` | bootstrap vs full API contract |

## Health

```bash
./scripts/hostinger-health.sh --wait 30
# or
curl -s http://127.0.0.1:8787/api/health | jq .
```

After certbot: `curl -s https://cockpit.example.com/api/health`
