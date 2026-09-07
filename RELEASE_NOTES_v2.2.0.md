# Cockpit 2.2.0 — Visual Multiview

Same product capability as v2.1.4, new fieldset terminal skin + real staging multiview.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.2.0/install.sh | bash
```

Web + Hostinger:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.2.0/install.sh | COCKPIT_INSTALL_WEB_BUILD=1 bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.2.0/scripts/install-hostinger.sh | sudo bash
```

## What's new

- **Fieldset panels** — cyan 1px border, title-in-border; near-black + cyan chrome + magenta active; monospace
- **dockview-react@8.2.0** staging multiview at `/splash/staging`
- **Drag palette** — Agents, Computers, Files into canvas; layout persist `cockpit.layout.v3`
- **Themes** — fieldset-dark, ghui-cyan, high-contrast; switcher in SETUP + staging; persist `cockpit.theme`
- **Charts** — ResizeObserver + uPlot graph panel
- **Pre-auth** `/splash` · **post-auth** `/splash/staging` · fullscreen toggle
- **tokens.css** + CSS modules per panel + `app/STYLE.md`

## Unchanged (v2.1.4 baseline)

- Foot size-owning · 6-chip bar · MODELS=`m` in COMPUTERS · Funnel/Serve OFF · Origin≠bus · PTY · gh device-flow

## Verify

```bash
./bench/cockpit/capability-matrix.sh
./bench/cockpit/hostinger-h0-verify.sh
./bench/cockpit/capture-screenshots.sh
command -v cockpit   # PATH via install.sh
```
