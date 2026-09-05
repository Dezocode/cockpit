# t728u-next2 kick packet — BENCH bar complete (Proctor validation card)

**Card:** `cursor-bench-bar-complete-t728u-next2`  
**Branch:** `cursor/bench-ghui-7ed3` (draft PR #4 — never merge/force-push)  
**Prior head:** `7e789b5`

## Prior FAIL CPRs

| Capture | Score ref | Issue |
|---|---|---|
| 002855 | live CPR t728u-next | Totoro/wallpaper bleed; packed chip read; density noisy; double chrome |
| 001318 | live CPR t728u | Totoro/wallpaper bleed; packed chip read; density noisy |
| 233909 | `bench/schemas/ui/scores/t293u-live-233909.yaml` | single-chip, double chrome, density |
| 235917 | prior live CPR | double row tmux strip + product nav |

**Approved target:** `/workspace/proofs/approved-style/bench-ghui-approved-t533u.png`

## This run (t728u-next2)

| Schema | Fix |
|---|---|
| top-chrome / pane tabs | `soften_tmux_window_strip` — status bottom, blank COCKPIT badge, omarchy-flat tmux window-style |
| visual-density | quieter L3 tag line (model · role · status); CHIP_PAD_COLS + blank row between N chips |
| omarchy-theme | `Normal`/`EndOfBuffer`/`StatusLine` on `omarchy_flat`; pane winhighlight warm band; tmux `window-style` opaque |
| multi-chip | N filled chips for N backlinks; separate 2-line boxes with spacer rows |
| winseparator | durable guard @ 29a54dd+ (fillchars + pcall) |
| touch+keyboard | `on_mouse` SGR proof in `test-bench-touch-t728u.sh`; keyboard in `test-bench.sh` |
| resize | `VimResized` + distinct sha256 at 220×40 and 160×32 in `test-bench-complete-t728u.sh` |

## Harness tests

```bash
bash tests/test-bench-ghui-style.sh
bash tests/test-bench-agency-style.sh
bash tests/test-bench-complete-t728u.sh
bash tests/test-bench-touch-t728u.sh
bash tests/test-bench.sh   # requires nvim in PATH
```

## Live CPR (this run)

- Text CPR: `/workspace/proofs/bench-bar-t728u-next2-live-20260905-003600.txt`
- sha256: `2dce0af47ca96aafe8f4aef2179876677cd383b16cbccded4da7b97a092401bf`
- Multi-chip: 2× `worker_deck_run` on separate rows (not one packed box)
- Omarchy-flat: no Totoro/wallpaper text bleed; tmux window-style + nvim canvas opaque
- Footer: single `t524u ghui` line

## Live CPR path (Canon — dezohost)

1. Land draft PR #4 on dezohost (Dezocode merges; agent stays draft).
2. `CPR live BENCH` on dezohost cockpit session.
3. Capture screenshot to `/workspace/proofs/bench-bar-t728u-live-<timestamp>.png`.
4. Proof hash **must differ** from: approved PNG (t533u), CPR 002855, 001318, 233909, and 235917.
5. Score live capture under `bench/schemas/ui/scores/t728u-live-<id>.yaml`.
6. Soft-steer only from Canon thereafter — no agent self-merge.

## Deny kick

`sol-v1.7.1`, `local/*`, `Qwen`
