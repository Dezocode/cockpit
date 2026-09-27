#!/usr/bin/env bash
# Shared test sandbox: temp HOME, fake bin, sanitized env, tmux server isolation.
set -euo pipefail

FIXTURE_REPO_ROOT=""
FIXTURE_TEST_ROOT=""
FIXTURE_HOME=""
FIXTURE_FAKEBIN=""
FIXTURE_SAVED_TMUX=""

fixture_init() {
  local name=${1:-cockpit-test}
  FIXTURE_REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
  FIXTURE_TEST_ROOT="$(mktemp -d "/tmp/${name}.XXXXXX")"
  FIXTURE_HOME="$FIXTURE_TEST_ROOT/home"
  FIXTURE_FAKEBIN="$FIXTURE_TEST_ROOT/bin"
  mkdir -p "$FIXTURE_HOME" "$FIXTURE_FAKEBIN"

  FIXTURE_SAVED_TMUX="${TMUX:-}"
  export TMUX=
  export TMUX_TMPDIR="$FIXTURE_TEST_ROOT/tmux-server"
  mkdir -p "$TMUX_TMPDIR"

  export HOME="$FIXTURE_HOME"
  export XDG_CONFIG_HOME="$FIXTURE_HOME/.config"
  mkdir -p "$XDG_CONFIG_HOME"
  export PATH="$FIXTURE_HOME/.local/bin:$FIXTURE_FAKEBIN:$FIXTURE_REPO_ROOT/bin:/usr/bin:/bin"
  unset ZDOTDIR COCKPIT_SESSION CODEX_COCKPIT_SESSION COCKPIT_AUTH_HOME COCKPIT_CONFIG_HOME

  fixture_cleanup() {
    tmux kill-server 2>/dev/null || true
    rm -rf "$FIXTURE_TEST_ROOT"
    if [[ -n "$FIXTURE_SAVED_TMUX" ]]; then
      export TMUX="$FIXTURE_SAVED_TMUX"
    else
      unset TMUX
    fi
  }
  trap fixture_cleanup EXIT
}
