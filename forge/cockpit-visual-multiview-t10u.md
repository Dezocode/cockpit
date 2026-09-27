# t10u — Cockpit 2.2 Visual Multiview (Forge Gospel)

**Card:** `cursor-cockpit2-visual-multiview-t12u` · **Authority:** t10u/t12u  
**Repo:** https://github.com/Dezocode/cockpit  
**Release:** ≥ v2.2.0 · **Baseline:** v2.1.4 (zero regression)  
**Report mirror:** `/workspace/bench/cursor/reports/t10u-cockpit-visual-multiview-gospel.md`

Style: fieldset terminal console — cyan border, near-black, magenta active, monospace. **STYLE ONLY** from Canon PNG if provided — never LMS/course content.

Proofs: `/workspace/proofs/t72u/t384u-live-spa/`

---

## One-line goal

Same capability as v2.1.4, new fieldset skin + real staging multiview at `/splash/staging`.

---

## Ship list

1. **Fieldset panels** — `FieldsetPanel`, `tokens.css`, CSS modules in `app/src/panels/`, `app/STYLE.md`
2. **Themes** — `fieldset-dark`, `ghui-cyan`, `high-contrast`; `cockpit.theme` persist; switcher SETUP + staging
3. **Routes** — pre-auth `/splash` · post-auth `/splash/staging` · legacy `/workspace`
4. **Multiview** — dockview-react@8.2.0; drag Agents/Computers/Files; `cockpit.layout.v3`; fullscreen
5. **Charts** — ResizeObserver + uPlot graph panel
6. **install.sh** — `# Cockpit PATH` + `alias cockpit="cockpit"`
7. **Release** — tag v2.2.0+, GitHub Release assets, Hostinger scripts unchanged envelope

---

## KEEP / DENY

**KEEP:** Foot size-owning · 6-chip bar · MODELS=`m` in COMPUTERS · Funnel/Serve OFF · Origin≠bus · PTY · gh device-flow · all TUI pages

**DENY:** secrets in shots · force-push · TUI product-socket kill · Electron default · Qwen/sol-v1.7.1 · 7th chip · LMS copy

---

## Done-line

```
Release ≥v2.2.0          → github.com/Dezocode/cockpit/releases/tag/v2.2.0
Hostinger fresh+health   → hostinger-h0-verify.sh green
Login + staging          → /splash + /splash/staging
≥3 themes token-only     → theme.ts + tokens.css
cockpit alias/PATH       → install.sh marker
t384u                    → capture-screenshots.sh
Zero regression          → capability-matrix 71/71 + surface-matrix
```

---

## Verify

```bash
./bench/cockpit/capability-matrix.sh
./bench/cockpit/hostinger-h0-verify.sh
./bench/cockpit/surface-matrix.sh
./bench/cockpit/capture-screenshots.sh
./proofs/t72u/t384u-live-spa/sync-from-capture.sh
```

Mirror: `bench/cursor/reports/t10u-cockpit-visual-multiview-gospel.md`
