# Duplication: legacy shims + identical config copies

Issue: https://github.com/Dezocode/cockpit/issues/19

## Problem

Legacy-compat boilerplate and byte-identical config copies multiply
the files that must be touched for any convention change — and edits
to the wrong copy are silently discarded by the installer.

### Clusters

- **D2 — 37 legacy `codex-cockpit-*` shims.** `bin/codex-cockpit-*`:
  34 byte-identical 12-line self-dispatching shims (same md5), 3 lib
  shims, 1 Python variant. All derive the canonical `cockpit-*` name
  from `$0`.
- **D3 — Identical tmux overlays.** `stage/tmux/cockpit.conf` ≡
  `stage/tmux/codex-cockpit.conf` (112 lines, byte-identical).
  `install.sh:138-142` already copies the canonical to BOTH
  destinations — the second source file is dead weight; edits to it
  are overwritten.
- **D4 — Identical shell rc snippets.**
  `stage/shell/cockpit.bashrc` ≡ `stage/shell/codex-cockpit.bashrc`
  (12 lines; the `cpr()` helper). `install.sh:155-166` inlines the
  content directly, so the stage files may be fully redundant.
- **D5 — `AGENTS.md` == `CLAUDE.md`.** Byte-identical; any edit must
  be made twice or agent instructions silently fork.

## Impact

Convention changes (dispatch logic, overlay, rc helper, agent
instructions) require N synchronized edits with no mechanism
enforcing it; wrong-copy edits are silently dropped (D3 is the sharp
edge — the installer overwrites the duplicate).

## Recommended consolidation

Replace the 37 shims with symlinks to one dispatcher (or to canonical
targets); delete `stage/tmux/codex-cockpit.conf` (keep the copy
step); collapse the rc snippets to one file/two destinations; make one
of AGENTS.md/CLAUDE.md a symlink or pointer.

## Steering prompt (agent-executable)

> In Dezocode/cockpit, collapse the legacy-compat duplication per
> https://github.com/Dezocode/cockpit/issues/19. (1) Replace the 37
> `bin/codex-cockpit-*` shims with symlinks to a single dispatcher
> (or to their canonical `cockpit-*` targets); keep `$0`-derived
> dispatch working — test every shim name. (2) Delete
> `stage/tmux/codex-cockpit.conf` (byte-identical to
> `stage/tmux/cockpit.conf`); keep the `install.sh:138-142` copy step
> writing both destinations. (3) Collapse the identical
> `stage/shell/{cockpit,codex-cockpit}.bashrc` to one source; keep
> `install.sh:155-166` behavior. (4) Make one of AGENTS.md/CLAUDE.md a
> symlink to the other (check the repo's tooling follows symlinks
> first). Run `install.sh` in a sandbox and the shell tests after.
> Open a PR; do not merge it yourself.
