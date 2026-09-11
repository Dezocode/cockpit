# t72u — t384u live SPA ugly baseline proofs

Card lineage: t72u residuals · t10u/t12u visual multiview · Cockpit 2.2.0

These are **ugly baseline proofs** — functional evidence, not marketing polish. Style ref is fieldset terminal console only (no LMS content).

## Populate

```bash
./proofs/t72u/t384u-live-spa/sync-from-capture.sh
```

Source capture: `bench/cockpit/capture-screenshots.sh` → `bench/cockpit/screenshots/t384u/`

## Expected files

| File | Gate |
|------|------|
| `login-splash.png` | Pre-auth `/splash?screenshot=login` |
| `staging-empty.png` | Empty staging canvas |
| `staging-3-panels.png` | Agents + Computers + Files |
| `graph-resize.png` | uPlot ResizeObserver |
| `fullscreen.png` | Staging fullscreen |
| `focus-rings.png` | Theme focus rings |
| `hostinger-health.json` | GET `/api/health` green |
| `hostinger-fresh-install-health.json` | Fresh install at `/opt/cockpit*` |
| `MANIFEST.json` | Capture metadata |

## Gospel

- `/workspace/bench/cursor/reports/t10u-cockpit-visual-multiview-gospel.md`
- `/workspace/forge/cockpit-visual-multiview-t10u.md`

## Release

https://github.com/Dezocode/cockpit/releases/tag/v2.2.0
