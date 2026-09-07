# t10u / t12u — Cockpit 2.2 Visual Multiview Gospel

**Authority:** Dezocode gospel · Card `cursor-cockpit2-visual-multiview-t12u`  
**Repo:** https://github.com/Dezocode/cockpit  
**Baseline:** v2.1.4 — DO NOT regress features  
**Release floor:** ≥ v2.2.0  
**Mirror:** `/workspace/forge/cockpit-visual-multiview-t10u.md`

Style reference: **fieldset terminal console aesthetic ONLY** — near-black canvas, cyan 1px fieldset borders, title-in-border, magenta active chrome, monospace. **DENY** LMS/course copy. Style-ref PNG (STYLE ONLY): ask Canon if image not on Thesis box.

Ugly baseline proofs: `/workspace/proofs/t72u/t384u-live-spa/`

---

## Goal

Same product capability as v2.1.4, new skin + real staging multiview.

| Surface | Route | Purpose |
|---------|-------|---------|
| Pre-auth splash | `/splash` | GitHub device-flow login |
| Post-auth staging | `/splash/staging` | dockview multiview canvas |
| Legacy workspace | `/workspace` | v2.1.4 dockview parity (zero regression) |

---

## Implement (2.2 visual)

### Fieldset + tokens

- `app/src/styles/tokens.css` — CSS vars **only** in panels (no hardcoded accent hex in `app/src/panels/*.module.css`)
- `FieldsetPanel` — cyan 1px border, title-in-border (`legend` pattern)
- CSS modules per panel under `app/src/panels/`
- Style guide: `app/STYLE.md`

### Themes (≥3, token-only)

| ID | Key |
|----|-----|
| `fieldset-dark` | default near-black + cyan + magenta active |
| `ghui-cyan` | t533u chip palette extended |
| `high-contrast` | accessibility |

- Persist: `localStorage` key `cockpit.theme`
- Switcher: SETUP page + staging toolbar

### Staging multiview

- **dockview-react@8.2.0**
- Drag palette: **Agents**, **Computers**, **Files** → canvas
- Layout persist: `cockpit.layout.v3` (serialized dockview + panel list)
- Fullscreen toggle on staging chrome
- Graph panel: **ResizeObserver** + **uPlot**

### KEEP (v2.1.4 baseline)

- Foot size-owning on dezohost
- **6-chip** AGENT bar: PRS · provider · FILES · MEMORY · MODEL · RESTART (**no 7th**)
- MODELS = view `m` inside COMPUTERS (not separate window)
- Funnel OFF · Serve OFF
- Origin ≠ intercom bus
- PTY (node-pty web + tauri-plugin-pty desktop)
- gh device-flow splash; tokens OS keyring / Stronghold only

### DENY

- Secrets in screenshots
- force-push
- product-socket TUI kill
- Electron default
- local Qwen / sol-v1.7.1
- 7th chip
- LMS / course content copy

---

## Baked pins

| Package | Pin |
|---------|-----|
| React | 19 |
| Vite | 6 |
| dockview-react | 8.2.0 |
| react-resizable-panels | 4.12.3 |
| @xterm/xterm | 6 |
| uPlot | 1.6.x |
| Tauri | 2.11.x (optional desktop bundle) |

---

## Hostinger H0

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.2.0/scripts/install-hostinger.sh | sudo bash
# gospel wrapper:
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/v2.2.0/scripts/hostinger-grok-build.sh | sudo bash
```

Install root: **`/opt/cockpit`** — DENY `/root/.grok`, `saul-go`.

Health contract: `GET /api/health` → `status: green`, `checks.hostinger: configured`.

---

## install.sh — cockpit PATH/alias

Appended to `$COCKPIT_SHELL_RC` (default `~/.bashrc`):

```bash
# Cockpit PATH
export PATH="$HOME/.local/bin:$PATH"
if command -v cockpit >/dev/null 2>&1; then
  alias cockpit="cockpit"
fi
```

Verify: `command -v cockpit` → `$HOME/.local/bin/cockpit`

---

## Done-line (EOD America/Chicago)

| # | Gate | Verify |
|---|------|--------|
| 1 | Release ≥ v2.2.0 | https://github.com/Dezocode/cockpit/releases/tag/v2.2.0 |
| 2 | Hostinger fresh + health green | `./bench/cockpit/hostinger-h0-verify.sh` |
| 3 | Login splash + staging multiview | `/splash?screenshot=login`, `/splash/staging` |
| 4 | ≥3 themes, token-only panels | `app/src/lib/theme.ts`, `tokens.css` |
| 5 | cockpit alias/PATH | `install.sh` `# Cockpit PATH` marker |
| 6 | t384u screenshot set | `./bench/cockpit/capture-screenshots.sh` |
| 7 | Zero regression vs v2.1.4 | `./bench/cockpit/capability-matrix.sh` (71/71) + `./bench/cockpit/surface-matrix.sh` |

Soft holds **BANNED**. Soft_steer ≠ score.

---

## Verification commands

```bash
./bench/cockpit/capability-matrix.sh
./bench/cockpit/hostinger-h0-verify.sh
./bench/cockpit/surface-matrix.sh
./bench/cockpit/tui-harness.sh
./bench/cockpit/capture-screenshots.sh
./proofs/t72u/t384u-live-spa/sync-from-capture.sh   # populate ugly baseline proofs
command -v cockpit
curl -s http://127.0.0.1:8787/api/health | jq .
```

---

## t384u evidence paths

Capture output (gitignored): `bench/cockpit/screenshots/t384u/`

| File | Scene |
|------|-------|
| `login-splash.png` | Pre-auth device-flow splash |
| `staging-empty.png` | Post-auth empty canvas |
| `staging-3-panels.png` | Agents + Computers + Files |
| `graph-resize.png` | uPlot + ResizeObserver |
| `fullscreen.png` | Fullscreen staging |
| `focus-rings.png` | Theme switcher focus |
| `hostinger-health.json` | `/api/health` green |
| `hostinger-fresh-install-health.json` | Fresh `/opt/cockpit*` install |

Canonical ugly proofs copy: `/workspace/proofs/t72u/t384u-live-spa/`

---

## Canon cross-links

| Topic | Path |
|-------|------|
| t847u Tauri gospel | `bench/cursor/reports/t847u-cockpit2-gospel-prompt.md` |
| Hostinger canon map | `tmp/t847u/README.md` |
| Forge oneshot (t847u) | `forge/cockpit-redesign-oneshot.md` |
| Release notes | `RELEASE_NOTES_v2.2.0.md` |
| Visual style | `app/STYLE.md` |

---

## Residuals

| Item | Status |
|------|--------|
| Tauri `.deb`/`.AppImage` | CI optional; web+H0 green without |
| Live Hostinger VPS + certbot | Scripts ready; TLS on VPS |
| Style-ref PNG on Thesis | Ask Canon if not attached |
| PR merge to main | Draft until human review |
