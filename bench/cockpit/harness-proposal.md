# Cockpit 2 harness proposal (bench/cockpit)

## Goals

- Regression pack for TUI + GUI parallel upgrade
- Isolated TMUX_TMPDIR for tests (no product socket collision)
- Input matrix: keyboard vs touch modality preserved in TUI

## Harness layout

```
bench/cockpit/
  capability-matrix.sh   # gospel checkbox runner
  doctor.sh              # preflight toolchain + health
  capture-screenshots.sh # t384u evidence (playwright/curl)
  harness-proposal.md    # this file
  audit-proposal.md
  screenshots/t384u/
```

## Test isolation

```bash
export TMUX_TMPDIR="${TMPDIR:-/tmp}/cockpit-harness-$$"
mkdir -p "$TMUX_TMPDIR"
export COCKPIT_CONFIG_HOME="$TMUX_TMPDIR/config"
./install.sh
./tests/test-auth-setup.sh
```

## Proctor write surface

BENCH directory is read-only for agents except Proctor role (`agent-008` in fixtures).

## CI integration

```bash
cd app && pnpm install && pnpm build
bash bench/cockpit/capability-matrix.sh
```
