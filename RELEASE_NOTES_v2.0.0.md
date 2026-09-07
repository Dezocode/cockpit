# Cockpit 2.0.0

Multi-agent terminal IDE — Tauri 2 + React web GUI, parallel TUI upgrade.

## Install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.0.0/install.sh | bash
```

Web + Hostinger:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.0.0/install.sh | COCKPIT_INSTALL_WEB_BUILD=1 bash
```

Hostinger grok-build lane:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.0.0/deploy/hostinger-grok-build-install.sh | bash
```

## Artifacts

| File | Contents |
|------|----------|
| `cockpit-2.0.0-linux-x64.tar.gz` | Full product: TUI + web + fixtures + deploy |
| `cockpit-2.0.0-web.tar.gz` | Web GUI + API server + systemd/nginx |
| `*.deb` / `*.AppImage` | Tauri desktop (when built on Linux CI) |

## Health check

```bash
cockpit-web &
curl -s localhost:8787/api/health | jq .
```

## Gospel

Seed `cockpit-20260907` · ≥24 fixture agents · TUI zero regression · Foot size-owning preserved.

Envelope: **frontier_subscription** / Hostinger subscription — local Qwen / sol-v1.7.1 denied.

## Capability matrix

```bash
./bench/cockpit/capability-matrix.sh
```
