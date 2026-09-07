# t847u — Canon Hostinger draft ↔ in-repo alignment

Canon draft box path: `/workspace/tmp/t847u/`  
In-repo canonical paths (this PR lineage — do not duplicate logic here):

| Canon draft file | In-repo gospel path |
|------------------|---------------------|
| `scripts/hostinger-grok-build.sh` | `scripts/hostinger-grok-build.sh` → wraps `deploy/hostinger-grok-build-install.sh` |
| `install-hostinger.sh` | `scripts/install-hostinger.sh` |
| `packaging/systemd/cockpit-web.service` | `packaging/systemd/cockpit-web.service` |
| `packaging/systemd/cockpit-web-heal.sh` | `packaging/systemd/cockpit-web-heal.sh` |
| `packaging/nginx/cockpit.conf` | `packaging/nginx/cockpit.conf` |
| `health-server.js` | `packaging/health-server.js` |

## Deploy recipe (canonical)

```bash
./deploy/hostinger-grok-build-install.sh
```

## Gospel curl path (wrapper — same recipe)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.4/scripts/hostinger-grok-build.sh | sudo bash
```

## Install root

**`/opt/cockpit`** — Canon VPS deploy. Saul `/root/.grok` and `saul-go` **untouched**.

## Health

```bash
curl -s http://127.0.0.1:8787/api/health | jq .
node packaging/health-server.js   # bootstrap probe (optional)
./scripts/hostinger-health.sh     # install verification
```

Full API after install: `node /opt/cockpit/app/dist-server/index.js` via systemd.  
Bootstrap probe only: `node packaging/health-server.js` (residual — see `bench/cockpit/H0-HEALTH-CONTRACT.md`).
