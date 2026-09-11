# Duplication: bin/ helpers shadow cockpit-lib

Issue: https://github.com/Dezocode/cockpit/issues/18

## Problem

Several `bin/` helpers carry local copies of functions that already
exist (identically or better) in `bin/cockpit-lib`, which they already
source. The worst case: a canonical fix exists but never takes effect
because a stale local shadows it.

### Clusters

- **D9 — `shell_quote()` shadows canonical `cockpit_shell_quote()`.**
  `bin/cockpit-reload-views:22` and `bin/cockpit-setup:49` define
  byte-identical locals; `bin/cockpit-lib:81` has the identical
  canonical — and both scripts already source cockpit-lib. A quoting
  fix in cockpit-lib would be silently shadowed.
- **D8 — `update_git_chrome()` diverged (NEAR).**
  `bin/cockpit-adapt:129` vs `bin/cockpit-diff:44`: same label format,
  but adapt shells out to plain `git` while diff uses the
  `safe.directory` wrapper array; state colors use different theme
  keys. A branch-detection or safe.directory fix in one copy never
  reaches the other.
- **D7 — `tmux_fg()` identical** in `bin/cockpit-adapt:107`,
  `bin/cockpit-diff:39`; belongs in cockpit-lib next to
  `cockpit_theme_hex`.
- **D10 — `now_ms()` identical** in `bin/cockpit-bar:186`,
  `bin/cockpit-pointer:15`; the bar's own comment says they must agree
  — currently by copy-paste. If one fallback changes, tap debounce
  double-fires.
- **D11 — `window_of()`:** pointer has an empty-target guard,
  `ensure-bar:35` does not.
- **D12 — `pane_for()`:** adapt:95 simple resolver vs
  reload-views:29 extended fallback table; new roles resolve in only
  one path.
- **D13 — `pick()` menus** (`cockpit-auth:117` vs
  `cockpit-runtime:234`): same numbered-menu skeleton on
  `cockpit_auth_*` lib, input validation copy-pasted.
- **D14 — `clear_screen()`/`maybe_render()`**
  (`cockpit-mermaid-watch:73/151` vs `cockpit-diff:75/163`): already
  diverged once (diff's hidden-branch refresh).

## Impact

Fixes applied to the canonical implementation silently fail to take
effect (D9 — quoting, the security-relevant one); visible git chrome
can disagree between views (D8); debounce/input-validation drift
(D10, D13).

## Recommended consolidation

Move each helper into `bin/cockpit-lib` (or `cockpit-auth-lib` for
D13) as `cockpit_<name>`; delete the locals; update call sites.
Parameterize where behavior genuinely differs (D8: status + git_cmd;
D12: fallback table).

## Steering prompt (agent-executable)

> In Dezocode/cockpit, deduplicate the bin/ helpers per
> https://github.com/Dezocode/cockpit/issues/18. For each cluster D7–D14:
> (1) move the helper into `bin/cockpit-lib` as `cockpit_<name>` (D13
> goes to `cockpit-auth-lib`); (2) delete the local copies; (3) update
> call sites. Start with D9 (`shell_quote()` in
> `bin/cockpit-reload-views:22` and `bin/cockpit-setup:49` shadowing
> `cockpit-lib:81`) — it is quoting logic, so verify with the
> existing shell tests. Parameterize genuine differences instead of
> forcing sameness: D8 takes a git_cmd + status theme, D12 takes a
> fallback table. Preserve each script's current observable behavior;
> run the repo's shell test suite after. Open a PR; do not merge it
> yourself.
