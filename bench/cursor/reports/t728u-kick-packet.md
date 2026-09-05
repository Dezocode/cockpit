# t728u kick packet — BENCH bar complete (Thesis mint ack)

**Card:** `cursor-bench-bar-complete-t728u`  
**Branch:** `cursor/bench-ghui-7ed3`  
**PR:** #4 (draft only — never merge/force-push)

## Prior FAIL CPRs

| Capture | Score ref | Issue |
|---|---|---|
| 233909 | `bench/schemas/ui/scores/t293u-live-233909.yaml` | single-chip, double chrome, density |
| 235917 | prior live CPR | double row tmux strip + product nav |

**Approved target:** `/workspace/proofs/approved-style/bench-ghui-approved-t533u.png`

## This run (t728u)

| Schema | Fix |
|---|---|
| top-chrome / pane tabs | `soften_tmux_window_strip` — status bottom, blank COCKPIT badge, dim shell tabs only |
| visual-density | warm opaque `PANE_BG`; theme wallpaper bg no longer overrides pane band |
| multi-chip | N filled chips for N backlinks (unchanged; fixture proof) |
| winseparator | durable guard @ 29a54dd+ (fillchars + pcall) |
| touch+keyboard | `on_mouse` + j/k drill; `test-bench.sh` tmux proof |
| resize | `VimResized` + `test-bench-complete-t728u.sh` at 220×40 and 160×32 |

## Harness tests

```bash
bash tests/test-bench-ghui-style.sh
bash tests/test-bench-agency-style.sh
bash tests/test-bench-complete-t728u.sh
bash tests/test-bench.sh   # requires nvim in PATH
```

## Live CPR path (Canon)

1. Land draft PR #4 on dezohost (Dezocode merges; agent stays draft).
2. `CPR live BENCH` on dezohost cockpit session.
3. Capture screenshot to `/workspace/proofs/bench-bar-t728u-live-<timestamp>.png`.
4. Proof hash **must differ** from: approved PNG (t533u), CPR 233909, CPR 235917.
5. Score live capture under `bench/schemas/ui/scores/t728u-live-<id>.yaml`.
6. Soft-steer only from Canon thereafter — no agent self-merge.

## Deny kick

`sol-v1.7.1`, `local/*`, `Qwen`
