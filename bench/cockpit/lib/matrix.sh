#!/usr/bin/env bash
# Shared pass/fail/warn counters and trailer for cockpit bench matrices.
set -euo pipefail

MATRIX_PASS=0
MATRIX_FAIL=0
MATRIX_WARN=0
MATRIX_TITLE=${MATRIX_TITLE:-cockpit matrix}

matrix_begin() {
  MATRIX_TITLE=${1:-$MATRIX_TITLE}
  MATRIX_PASS=0
  MATRIX_FAIL=0
  MATRIX_WARN=0
  printf '%s\n\n' "$MATRIX_TITLE"
}

matrix_check() {
  local name=$1 result=$2
  case "$result" in
    ok)
      printf '  ✓ %s\n' "$name"
      MATRIX_PASS=$((MATRIX_PASS + 1))
      ;;
    warn)
      printf '  ~ %s\n' "$name"
      MATRIX_WARN=$((MATRIX_WARN + 1))
      ;;
    *)
      printf '  ✗ %s\n' "$name"
      MATRIX_FAIL=$((MATRIX_FAIL + 1))
      ;;
  esac
}

matrix_end() {
  printf '\nmatrix: pass=%d warn=%d fail=%d\n' "$MATRIX_PASS" "$MATRIX_WARN" "$MATRIX_FAIL"
  [[ "$MATRIX_FAIL" -eq 0 ]]
}
