# Duplication: bench matrix + test-fixture scaffolds

Issue: https://github.com/Dezocode/cockpit/issues/20

## Problem

Capability-matrix verification scripts and test fixtures share
copy-pasted scaffolds that have already started to drift.

### Clusters

- **D15 — Bench matrix `check()` scaffolds ×4 (NEAR).**
  `bench/cockpit/hostinger-h0-verify.sh:9` ≡
  `bench/cockpit/surface-matrix.sh:9`; `input-matrix.sh:9` condensed
  variant; `capability-matrix.sh:10` adds a `warn` state. All four
  share the full scaffold (`set -euo pipefail` → root → `pass=0/fail=0`
  → `check()` → trailer `pass=/fail=`). `capability-matrix` already
  drifted (adds `warn=`) — trailer consumers must now handle two
  formats.
- **D20 — Test sandbox fixture scaffold ×6 (NEAR).**
  `tests/test-setup-flows.sh:8-23`, `test-auth-setup.sh:8-20`,
  `test-setup-agent-flow.sh:8-19`, `test-agent-profile.sh:8-16`,
  `test-cpr-plugin.sh:8-17`, `test-termius-touch.sh:9-24`: mktemp
  sandbox, fake HOME/bin, cleanup trap, sanitized env. A fixture bug
  (e.g. the TMUX-socket leak `test-termius-touch` warns about — a
  missing test session becomes `tmux kill-server` on the real session)
  fixed in one test never propagates.

## Impact

Output-contract drift breaks trailer parsing (D15); sandbox-setup
bugs stay local to one test file instead of being fixed once (D20 —
including a tmux-server footgun).

## Recommended consolidation

- `bench/cockpit/lib/matrix.sh` with
  `matrix_begin`/`check`/`matrix_end` (standardize the trailer
  contract; decide the `warn=` question once).
- `tests/lib/fixture.sh` with `fixture_init <name>` (+ cleanup hook
  for termius's tmux server). Scripts keep only their check lists /
  specific bits.

## Steering prompt (agent-executable)

> In Dezocode/cockpit, extract the shared scaffolds per
> https://github.com/Dezocode/cockpit/issues/20. (1) Create
> `bench/cockpit/lib/matrix.sh` exporting
> `matrix_begin`/`check`/`matrix_end`; migrate the four bench scripts
> (`hostinger-h0-verify.sh`, `surface-matrix.sh`, `input-matrix.sh`,
> `capability-matrix.sh`) to it, standardizing the trailer contract
> (`pass=/fail=` — decide whether `warn=` becomes part of the
> contract or stays local). (2) Create `tests/lib/fixture.sh` exporting
> `fixture_init <name>` (mktemp sandbox, fake HOME/bin, cleanup trap,
> sanitized env) plus a cleanup hook for the termius tmux server;
> migrate the six test files to it, preserving each test's specific
> setup. (3) Run the full bench + test suites; verify trailer parsing
> still works for all four matrix scripts. Open a PR; do not merge it
> yourself.
