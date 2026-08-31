#!/usr/bin/env bash
# Codex paste-ack stub for inject+submit TUI regression (no live Codex).
set -euo pipefail

marker="${COCKPIT_PASTE_STUB_MARKER:-}"
state="${COCKPIT_PASTE_STUB_STATE:-}"

log_state() {
  [[ -n "$state" ]] || return 0
  printf '%s\n' "$1" >>"$state"
}

emit_marker() {
  [[ -n "$marker" ]] || return 0
  printf '%s\n' "$1" >"$marker"
}

submit() {
  emit_marker "SUBMITTED:${buf}"
  log_state "SUBMITTED:${buf}"
  printf '\nSUBMITTED:%s\n' "$buf"
}

printf '› \n'
log_state ready

buf=""
idle_ticks=0

while true; do
  if IFS= read -r -n 1 -t 0.05 char 2>/dev/null; then
    idle_ticks=0
    [[ -n "$char" ]] || continue
    case "$char" in
      $'\n'|$'\r')
        if [[ -n "$buf" ]]; then
          emit_marker PREMATURE_ENTER
          log_state PREMATURE_ENTER
          printf '\nPREMATURE_ENTER\n'
          buf=""
        fi
        ;;
      *)
        buf+=$char
        ;;
    esac
  elif [[ -n "$buf" ]]; then
    idle_ticks=$((idle_ticks + 1))
    if ((idle_ticks >= 5)); then
      printf '\n› [Pasted Content %d chars]\n' "${#buf}"
      log_state "INDICATOR:${#buf}"
      stty sane 2>/dev/null || true
      IFS= read -r _ || true
      submit
      exit 0
    fi
  fi
done
