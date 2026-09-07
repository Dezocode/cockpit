# Cockpit 2.1.0

Full gospel ship — TUI + GUI parallel upgrade, Hostinger H0, Surface parity.

## Install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.0/install.sh | bash
```

Web + build:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.0/install.sh | COCKPIT_INSTALL_WEB_BUILD=1 bash
```

**Hostinger grok-build** (subscription runtime — DENY local Qwen/sol-v1.7.1):

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.1.0/deploy/hostinger-grok-build-install.sh | bash
```

## Release assets

| File | Contents |
|------|----------|
| `cockpit-2.1.0-linux-x64.tar.gz` | Full: TUI + web + fixtures + deploy + bench harness |
| `cockpit-2.1.0-web.tar.gz` | Web GUI + API + systemd/nginx |

## Health (must be green)

```bash
cockpit-web &
curl -s localhost:8787/api/health | jq .
# "status": "green"
```

## Verification (morning CT done-line)

```bash
./bench/cockpit/hostinger-h0-verify.sh    # 6/6
./bench/cockpit/capability-matrix.sh      # 45/45
./bench/cockpit/surface-matrix.sh         # 14/14 TUI↔GUI
./bench/cockpit/tui-harness.sh            # 6/6 TMUX_TMPDIR
./bench/cockpit/capture-screenshots.sh    # t384u evidence
```

## Gospel

- Product: **cockpit** (never codex-cockpit)
- 6-chip bar · MODELS=`m` in COMPUTERS · device-flow splash
- Foot size-owning · Funnel OFF · zero product-socket kill
- Seed `cockpit-20260907` · 24 fixture agents
- Envelope: **frontier_subscription** / Hostinger subscription only

## Residuals

- Tauri `.deb`/`.AppImage`: CI Rust ≥1.85 (web+H0 green without)
- Live VPS: certbot + `grok auth login` on Hostinger subscription runtime
