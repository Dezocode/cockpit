#!/usr/bin/env bash
# Rewrite the version in app/package.json, app/src-tauri/Cargo.toml [package]
# and the root `cockpit` entry of app/src-tauri/Cargo.lock; tauri.conf.json
# follows by reference ("../package.json"). Each file is rewritten into a temp
# file (mode copied) and moved into place; then scripts/check-versions.sh runs.
set -euo pipefail

usage() {
  printf 'usage: %s [--root DIR] X.Y.Z[-pre]\n' "${0##*/}" >&2
  exit 2
}

script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root="$script_root"
new=""
while (($#)); do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || usage
      root=$2
      shift 2
      ;;
    -*) usage ;;
    *)
      [[ -z "$new" ]] || usage
      new=$1
      shift
      ;;
  esac
done
[[ -n "$new" ]] || usage
if ! [[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  printf 'set-version: %q is not X.Y.Z[-pre]\n' "$new" >&2
  exit 2
fi

# shellcheck source=bin/cockpit-portable-lib
source "$script_root/bin/cockpit-portable-lib"

# rewrite FILE AWK_PROGRAM: the program must set `done` once per replacement.
rewrite() {
  local file=$1 prog=$2 tmp count
  tmp="$(mktemp "${file}.set-version.XXXXXX")"
  if ! awk -v v="$new" "$prog" "$file" >"$tmp"; then
    rm -f "$tmp"
    printf 'set-version: FAIL rewriting %s\n' "$file" >&2
    exit 1
  fi
  count="$(tail -n 1 "$tmp")"
  if [[ "$count" != "@@set-version 1" ]]; then
    rm -f "$tmp"
    printf 'set-version: FAIL %s: expected exactly one version line (%s)\n' "$file" "${count#@@set-version }" >&2
    exit 1
  fi
  # drop the trailing count marker line
  awk 'NR > 1 { print prev } { prev = $0 }' "$tmp" >"$tmp.body"
  mv "$tmp.body" "$tmp"
  cockpit_copy_mode "$file" "$tmp"
  mv "$tmp" "$file"
}

# package.json: the top-level "version" key (two-space indent).
rewrite "$root/app/package.json" '
  !n && /^  "version": "[^"]*",?$/ { sub(/"version": "[^"]*"/, "\"version\": \"" v "\""); n++ }
  { print }
  END { print "@@set-version " n+0 }'

# Cargo.toml: `version = "..."` inside the [package] table only.
rewrite "$root/app/src-tauri/Cargo.toml" '
  /^\[/ { in_pkg = ($0 == "[package]") }
  in_pkg && !n && /^version = "[^"]*"$/ { $0 = "version = \"" v "\""; n++ }
  { print }
  END { print "@@set-version " n+0 }'

# Cargo.lock: the [[package]] block named "cockpit" (a second match fails the count).
rewrite "$root/app/src-tauri/Cargo.lock" '
  /^\[\[package\]\]$/ { is_cockpit = 0 }
  /^name = "cockpit"$/ { is_cockpit = 1 }
  is_cockpit && /^version = "[^"]*"$/ { $0 = "version = \"" v "\""; n++; is_cockpit = 0 }
  { print }
  END { print "@@set-version " n+0 }'

"$script_root/scripts/check-versions.sh" --root "$root"
