# t12u — t384u Hostinger-LIVE proofs

Card: `cursor-cockpit2-visual-multiview-t12u-next` · Cockpit **v2.2.0** · Hostinger H0 green

Hostinger-LIVE capture profile (`COCKPIT_HOSTINGER=1`, `checks.hostinger: configured`).

## Populate

```bash
COCKPIT_CAPTURE_PROFILE=hostinger-live ./bench/cockpit/capture-screenshots.sh
./proofs/t12u/t384u-hostinger/sync-from-capture.sh
```

Source capture: `bench/cockpit/screenshots/t384u-hostinger/`

## Gate files (CLOSE ONLY)

| File | Gate |
|------|------|
| `focus-rings.png` | Theme switcher focus rings — **unique md5** |
| `fullscreen.png` | Staging fullscreen — **unique md5** |
| `graph-resize.png` | uPlot ResizeObserver — **unique md5** |
| `theme-ghui-cyan.png` | ghui-cyan theme (≥3 themes) |
| `login-splash.png` | Pre-auth `/splash?screenshot=login` |
| `staging-empty.png` | Empty staging canvas |
| `staging-3-panels.png` | Agents + Computers + Files |
| `hostinger-health.json` | GET `/api/health` green |
| `MANIFEST.json` | `md5_unique_ok: true` for gate trio |

## Gospel

- `bench/cursor/reports/t10u-cockpit-visual-multiview-gospel.md`
- `bench/cursor/reports/t12u-cockpit-visual-multiview-kick-packet.md`

## Release

https://github.com/Dezocode/cockpit/releases/tag/v2.2.0
