---
name: cockpit-bench
description: Keep Cockpit BENCH as a read-only Proctor SQLite mirror with a ghui-style model/run/backlink drill.
---

# BENCH page

Use `cockpit bench` to open the named `BENCH` page. It reads only the Proctor
mirror at `~/intercom/proctor` (or the explicit `COCKPIT_PROCTOR_HOME` test
mirror) and fails closed when the mirror is absent, unreadable, incomplete, or
contains a dangling backlink.

The mirror source is `db/runs.sqlite`, accompanied by `MODELS_INDEX.csv`.
Required tables are `models`, `runs`, and `run_links`. L1 renders models with
their stored `agent_class` badge; L2 renders runs; L3 renders a run and
resolved backlinks. Enter on a backlink follows its `to_run_id`, including
`sol_session_ref` links. Esc restores the jump history and pops drill levels.

The page is read-only. Proctor is the sole writer. Do not open Box truth or
its spreadsheets from the surface, write scores, attach to a remote session,
or create rows from missing data. If source truth is absent, show `ABSENT` and
no invented rows.

BENCH is a top-level named page, not a nested pane and not a toolbar chip.
