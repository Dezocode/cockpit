# t728u-next3 kick packet — BENCH bar complete (Proctor validation card)

**Card:** `cursor-bench-bar-complete-t728u-next3`  
**Branch:** `cursor/bench-ghui-7ed3` (draft PR #4 — never merge/force-push)  
**Prior head:** `3089af7` (was `be4c096`)

## Prior FAIL CPRs

| Capture | Score ref | Issue |
|---|---|---|
| 003648 | live CPR t728u-next2 | Totoro/wallpaper bleed; packed chip read; resize twin==full |
| 002855 | live CPR t728u-next | Totoro/wallpaper bleed; packed chip read; density noisy; double chrome |
| 001318 | live CPR t728u | Totoro/wallpaper bleed; packed chip read; density noisy |
| 233909 | `bench/schemas/ui/scores/t293u-live-233909.yaml` | single-chip, double chrome, density |
| 235917 | prior live CPR | double row tmux strip + product nav |

**Approved target:** `/workspace/proofs/approved-style/bench-ghui-approved-t533u.png`

## This run (t728u-next3)

| Schema | Fix |
|---|---|
| multi-chip | `CHIP_GAP_ROWS` spacer between N chips; chip fill clipped to box width (not full-line packed strip) |
| visual-density | quieter L3 tag line; CHIP_PAD_COLS + gap rows between chips |
| omarchy-theme | global + window `window-style`/`pane-border-style` on `OMARCHY_FLAT_BG`; re-apply on VimEnter/FocusGained/ColorScheme (survives `omarchy-theme-set-tmux`) |
| top-chrome | `soften_tmux_window_strip` — status bottom, blank COCKPIT badge, omarchy-flat tmux canvas |
| touch+keyboard | `on_mouse` SGR proof in `test-bench-touch-t728u.sh`; keyboard in `test-bench.sh` |
| resize | `VimResized` + distinct sha256 at 220×40 and 160×32 in `test-bench-complete-t728u.sh` (THIS stamp proofs, not prior KEEP) |
| winseparator | durable guard @ 29a54dd+ (fillchars + pcall) |

## Harness tests

```bash
bash tests/test-bench-ghui-style.sh
bash tests/test-bench-agency-style.sh
bash tests/test-bench-complete-t728u.sh
bash tests/test-bench-touch-t728u.sh
bash tests/test-bench-cpr-t728u-next3.sh
bash tests/test-bench.sh   # requires nvim in PATH
```

## Live CPR (this run)

- Text CPR: `/workspace/proofs/bench-bar-t728u-next3-live-20260905-004602.txt`
- sha256: `d7c2f6f77555e2c61a775238ea77095a59edcab4ceac3e75dd7101e9c9f341c0`
- Multi-chip: 2× `worker_deck_run` on separate rows with blank spacer (not one packed box)
- Omarchy-flat: global tmux + nvim canvas opaque; no Totoro/wallpaper text bleed
- Footer: single `t524u ghui` line
- Resize: wide `e233c9cf…` ≠ narrow `753cf7ff…` (distinct THIS stamp sha256)

## Live CPR path (Canon — dezohost)

1. Land draft PR #4 on dezohost (Dezocode merges; agent stays draft).
2. `CPR live BENCH` on dezohost cockpit session.
3. Capture screenshot to `/workspace/proofs/bench-bar-t728u-live-<timestamp>.png`.
4. Proof hash **must differ** from: approved PNG (t533u), CPR 003648, 002855, 001318, 233909, and 235917.
5. Score live capture under `bench/schemas/ui/scores/t728u-live-<id>.yaml`.
6. Soft-steer only from Canon thereafter — no agent self-merge.

## Deny kick

`sol-v1.7.1`, `local/*`, `Qwen`
