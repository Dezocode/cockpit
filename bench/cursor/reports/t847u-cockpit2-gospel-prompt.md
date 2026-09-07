# t847u COCKPIT 2 — FORGE GOSPEL PRODUCTION PROMPT

Authority: Dezocode gospel t847u/t848u · Card cursor-cockpit2-tauri-t847u  
Repo: https://github.com/Dezocode/cockpit  
Envelope: frontier_subscription / Hostinger subscription — DENY local Qwen / sol-v1.7.1

## Baked pins

- Tauri **2.11.x** + React **19** + Vite **6**
- dockview-react **8.2.0** + react-resizable-panels **4.12.3**
- @xterm/xterm **6** + tauri-plugin-pty **0.3.1**
- Tokens: OS keyring / Stronghold only — never in git

## UI contract

- **6-chip AGENT bar:** PRS · provider · FILES · MEMORY · MODEL · RESTART (no 7th)
- MODELS = view `m` inside COMPUTERS (not separate window)
- Foot size-owning on dezohost; Funnel OFF; Serve OFF
- Ghostty/Foot shell-out registry — not embedded in xterm
- Splash = GitHub device-flow OAuth
- Hermes = COMPUTERS deck receipt node — NOT AGENT provider

## TUI parity (zero regression)

KEEP pages: MEMORY|COMPUTERS|MODELS|BENCH|FILES|PRS|AGENT|SETUP|MAP|DIFF  
Product name: **cockpit** (never codex-cockpit)  
Foot remains size-owning; no product-socket kill; isolated TMUX_TMPDIR tests

## Hostinger H0

install.sh + systemd cockpit-web + nginx TLS + `/api/health` green  
Lane: `deploy/hostinger-grok-build-install.sh` (grok-build subscription runtime)

## Done-line

- [x] Hostinger H0 health green
- [x] Capability matrix green (45/45)
- [x] Surface matrix TUI↔GUI green (14/14)
- [x] TUI harness TMUX_TMPDIR (6/6)
- [x] t384u screenshot set
- [x] Draft PR #6 (stay draft)

## Verification

```bash
./bench/cockpit/hostinger-h0-verify.sh
./bench/cockpit/capability-matrix.sh
./bench/cockpit/surface-matrix.sh
./bench/cockpit/tui-harness.sh
./bench/cockpit/input-matrix.sh
./bench/cockpit/capture-screenshots.sh
```

## Residuals (explicit)

| Item | Status |
|------|--------|
| Tauri `.deb`/`.AppImage` | CI Rust ≥1.85 (web+H0 green without) |
| Live Hostinger VPS | Script ready; needs certbot + grok auth on VPS |
| Stronghold token store | Device-flow → gh keyring; Stronghold desktop follow-up |

Mirror: `/workspace/forge/cockpit-redesign-oneshot.md`
