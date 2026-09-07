# t12u Kick Packet — Cockpit 2.2 Visual Multiview

**Card:** `cursor-cockpit2-visual-multiview-t12u`  
**Receiver:** cursor_cloud / composer-2.5 / frontier_subscription

## Paste every turn (Proctor t238u)

```
card_id: cursor-cockpit2-visual-multiview-t12u
gospel: bench/cursor/reports/t10u-cockpit-visual-multiview-gospel.md
aspect: aspects/cockpit2-visual-multiview-t12u.md
style_ref: proofs/t12u/style-ref-fieldset.png (STYLE ONLY)
baseline: proofs/t72u/t384u-live-spa/
release_floor: v2.2.0
```

## Done-line EOD CT

1. GitHub Release ≥ v2.2.0 (notes + artifacts)
2. Fresh Hostinger install AFTER Release (Canon)
3. `install.sh` → cockpit PATH + idempotent alias
4. Pre-auth splash + post-auth staging dockview
5. Themes ≥3 token-only
6. t384u screenshots
7. Zero regression vs v2.1.4

## Final outlook (t650u)

**ADD:** fieldset panels, staging multiview, themes, alias, release artifacts  
**SUBTRACT (must_absent):** yellow-pill primary identity, equal-width-only as primary UX, hardcoded accent hex in panel modules, LMS copy, capability regressions

## Verify

```bash
./bench/cockpit/capability-matrix.sh
./bench/cockpit/hostinger-h0-verify.sh
./bench/cockpit/capture-screenshots.sh
./proofs/t72u/t384u-live-spa/sync-from-capture.sh
```

## PR + Release

- Draft PR until Release cut authority satisfied
- Release URL: https://github.com/Dezocode/cockpit/releases/tag/v2.2.0
