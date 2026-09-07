# Cockpit 2.1.1

Hostinger release-ready artifacts for Canon parallel deploy. Install root **`/opt/cockpit`** — separate from Saul `/root/.grok` and `saul-go`.

## Install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.1/install.sh | bash
```

Web + build:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.1/install.sh | COCKPIT_INSTALL_WEB_BUILD=1 bash
```

**Hostinger grok-build** (subscription runtime — DENY local Qwen/sol-v1.7.1):

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.1/scripts/hostinger-grok-build.sh | sudo bash
```

**Hostinger install** (no grok auth step):

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.1/scripts/install-hostinger.sh | sudo bash
```

## Release assets

| File | Contents |
|------|----------|
| `cockpit-2.1.1-linux-x64.tar.gz` | Full: TUI + web + fixtures + packaging + Hostinger scripts + bench harness |
| `cockpit-2.1.1-web.tar.gz` | Web GUI + API + packaging/systemd + nginx + Hostinger scripts |

## Packaging layout

| Path | Purpose |
|------|---------|
| `packaging/systemd/cockpit-web.service` | systemd unit + heal pre-start |
| `packaging/systemd/cockpit-web-heal.sh` | artifact/port heal; DENY grok/saul roots |
| `packaging/nginx/cockpit.conf` | TLS + explicit `GET /api/health` proxy |
| `scripts/install-hostinger.sh` | full Hostinger install → `/opt/cockpit` |
| `scripts/hostinger-grok-build.sh` | grok-build subscription lane |
| `scripts/hostinger-health.sh` | health probe |

## Health (must be green)

```bash
./scripts/hostinger-health.sh
# or
curl -s http://127.0.0.1:8787/api/health | jq .
# "status": "green", "hostinger": "configured"
```

## Verification (morning CT done-line)

```bash
./bench/cockpit/capability-matrix.sh
./bench/cockpit/hostinger-h0-verify.sh
./bench/cockpit/surface-matrix.sh
./bench/cockpit/capture-screenshots.sh   # t384u evidence
```
