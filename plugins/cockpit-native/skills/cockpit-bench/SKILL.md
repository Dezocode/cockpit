---
name: cockpit-bench
description: >-
  use when reading Cockpit BENCH / Proctor receipts — machine-readable
  1–2 command access to models, runs, backlinks, roster (t213u-5)
---
# Cockpit BENCH CLI (t213u/t524u/t533u)

Proctor truth: `~/intercom/proctor/` (runs.sqlite + MODELS_INDEX.csv + CROSSREF_LINKS.csv).
TUI is a view. Not VisiData. Stay draft.

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
- Data = sqlite/CROSSREF — never bench.json-only product path
- Visual TUI = t533u approved Miller PNG
- Soft-steer only while %0 Pursuing (t404u)
- t213u: resize must not obfuscate; touch+keyboard both live; idle panes cheap

