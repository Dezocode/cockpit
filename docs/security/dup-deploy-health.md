# Duplication: deploy + health-check logic ×4

Issue: https://github.com/Dezocode/cockpit/issues/17

## Problem

Deploy and health-check logic is implemented four times with real
divergence — including one path where the deploy steps execute TWICE
with different flags.

### Clusters

- **D18 — Hostinger deploy block duplicated + double-executed.**
  `install.sh:201-218` (inside the `COCKPIT_INSTALL_HOSTINGER` gate) vs
  `scripts/install-hostinger.sh:30-56`. Diverged:
  `install-hostinger.sh` uses `rsync -a --delete` (install.sh lacks
  `--delete`), different unit-file source paths, hard `systemctl
  restart` vs `restart || start`. Worse:
  `install-hostinger.sh` exports `COCKPIT_INSTALL_HOSTINGER=1` then
  runs `install.sh`, so install.sh's own Hostinger block fires too —
  systemd/nginx steps run twice with different flags.
- **D16 — CI health-prove step in two workflows.**
  `.github/workflows/ci.yml:36-52` vs `release-cockpit2.yml:39-56`
  (~17 identical lines); Python assertions diverged (strict
  `d["product"]` vs `.get()` diagnostics). pnpm+node setup block also
  verbatim-duplicated.
- **D17 — Health-poll logic ×4, canonical unused.** ci.yml +
  release-cockpit2.yml inline curl loops,
  `scripts/install-hostinger.sh:57-75`, and
  `scripts/hostinger-health.sh:1-14` (the dedicated canonical probe —
  called by NONE of the above).

## Impact

- Stale files survive under one deploy path (`--delete` mismatch).
- Releases can ship what CI would fail (weaker health assertion in the
  release workflow).
- Health-contract changes must land in four places.

## Recommended consolidation

1. Move the entire Hostinger gate block out of `install.sh` into
   `scripts/install-hostinger.sh` (or a shared
   `scripts/hostinger-deploy.sh`); guard against re-trigger when
   invoked from install-hostinger.sh (the double-execution bug).
2. Make `scripts/hostinger-health.sh` the single health probe (add a
   `--wait` flag); CI steps and install-hostinger.sh call it. Extract
   the CI prove-health step to a composite action.

## Steering prompt (agent-executable)

> In Dezocode/cockpit, consolidate deploy + health-check logic per
> https://github.com/Dezocode/cockpit/issues/17. (1) Move the
> Hostinger gate block out of `install.sh:201-218` into
> `scripts/install-hostinger.sh` (or a new shared
> `scripts/hostinger-deploy.sh`); remove the `COCKPIT_INSTALL_HOSTINGER`
> re-trigger so deploy steps run exactly once, with one flag set
> (decide `rsync --delete` vs not, `restart` vs `restart || start`, and
> the unit-file source path — document the choice). (2) Make
> `scripts/hostinger-health.sh` the single health probe: add a
> `--wait` flag, then replace the inline curl loops in
> `.github/workflows/ci.yml:36-52`, `release-cockpit2.yml:39-56`, and
> `scripts/install-hostinger.sh:57-75` with calls to it; unify the
> Python assertion on the stricter `d["product"]` form and extract the
> prove-health step (plus the duplicated pnpm+node setup block) to a
> composite action. (3) Run both workflows' affected jobs green.
> Open a PR; do not merge it yourself.
