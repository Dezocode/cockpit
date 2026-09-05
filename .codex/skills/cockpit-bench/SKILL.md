---
name: cockpit-bench
description: >-
  use when reading Cockpit BENCH / Proctor receipts — machine-readable
  1–2 command access to models, runs, backlinks, roster (t213u-5)
---
# Cockpit BENCH CLI (t213u/t524u/t533u)

Proctor truth: `~/intercom/proctor/` (runs.sqlite + MODELS_INDEX.csv + CROSSREF_LINKS.csv).
TUI is a view. Not VisiData. Stay draft.

The surface is mirror-only: `COCKPIT_PROCTOR_HOME` is allowed for isolated
tests, otherwise the root is `COCKPIT_INTERCOM_HOME/proctor` or
`~/intercom/proctor`. Missing schema, incomplete rows, and unresolved
`sol_session_ref` targets render `ABSENT`; Box truth and spreadsheets are not
opened. Proctor is the sole writer.

## Commands (prefer these)

```bash
export COCKPIT_INTERCOM_HOME="${COCKPIT_INTERCOM_HOME:-$HOME/intercom}"
bench path          # resolved root + db + csv paths
bench check         # status=ok + counts or fail-closed
bench models        # model_id TAB display (TSV)
bench runs MODEL_ID # runs for one model (TSV)
bench show-run ID   # run detail + backlink TAB lines
```

Roster (COMPUTERS):

```bash
cockpit-computers path
cockpit-computers roster
cockpit-computers models
```

## Locks
- Data = SQLite/CROSSREF — never an alternate JSON-only product path
- UI = three Miller columns: models (`agent_class`) → runs → run/backlinks
- Enter follows a resolved `to_run_id`; Esc restores the backlink jump stack
- Visual TUI = t533u approved Miller PNG
- Soft-steer only while %0 Pursuing (t404u)
- t213u: resize must not obfuscate; touch+keyboard both live; idle panes cheap
