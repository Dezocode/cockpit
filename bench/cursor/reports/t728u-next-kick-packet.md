# t728u-next kick packet — BENCH bar complete (Proctor validation card)

**Card:** `cursor-bench-bar-complete-t728u-next`  
**Branch:** `cursor/bench-ghui-7ed3` (draft PR #4 — never merge/force-push)  
**Prior head:** `776b6c7`

## Prior FAIL CPRs

| Capture | Score ref | Issue |
|---|---|---|
| 001318 | live CPR t728u | Totoro/wallpaper bleed; packed chip read; density noisy |
| 233909 | `bench/schemas/ui/scores/t293u-live-233909.yaml` | single-chip, double chrome, density |
| 235917 | prior live CPR | double row tmux strip + product nav |

**Approved target:** `/workspace/proofs/approved-style/bench-ghui-approved-t533u.png`

## This run (t728u-next)

| Schema | Fix |
|---|---|
| top-chrome / pane tabs | `soften_tmux_window_strip` — status bottom, blank COCKPIT badge (t736u) |
| visual-density | quieter L3 tag line (model · role · status); chip pad + spacer between N chips |
| omarchy-theme | `apply_omarchy_flat_bg` + `OMARCHY_FLAT_BG`; winblend=0; never inherit theme wallpaper bg |
| multi-chip | N filled chips for N backlinks; `CHIP_PAD_COLS` + blank row between chips |
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

## Live CPR path (Canon)

1. Land draft PR #4 on dezohost (Dezocode merges; agent stays draft).
2. `CPR live BENCH` on dezohost cockpit session.
3. Capture screenshot to `/workspace/proofs/bench-bar-t728u-live-<timestamp>.png`.
4. Proof hash **must differ** from: approved PNG (t533u), CPR 001318, CPR 233909, CPR 235917.
5. Score live capture under `bench/schemas/ui/scores/t728u-live-<id>.yaml`.
6. Soft-steer only from Canon thereafter — no agent self-merge.

## Deny kick

`sol-v1.7.1`, `local/*`, `Qwen`
