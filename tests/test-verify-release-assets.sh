#!/usr/bin/env bash
# scripts/verify-release-assets.sh: the 9-asset contract, SHA256SUMS written with
# cockpit_sha256 and verified line by line; each breakage exits 1 with its label.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
verify="$repo_root/scripts/verify-release-assets.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
v=2.3.0-dev

assets=(
  "cockpit-$v-linux-x64.tar.gz"
  "cockpit-$v-web.tar.gz"
  "cockpit-$v-darwin-arm64.tar.gz"
  "cockpit-$v-darwin-x64.tar.gz"
  "cockpit_${v}_amd64.deb"
  "cockpit_${v}_amd64.AppImage"
  "cockpit_${v}_aarch64.dmg"
  "cockpit_${v}_x64.dmg"
)
n=0
stage() {
  n=$((n + 1))
  local dir="$tmpdir/s$n" a
  mkdir -p "$dir"
  for a in "${assets[@]}"; do
    printf 'payload %s\n' "$a" >"$dir/$a"
  done
  "$verify" --write-sums "$dir" >/dev/null
  printf '%s\n' "$dir"
}

pass=0 fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n%s\n' "$1" "${2:-}"; fail=$((fail + 1)); }
expect() {
  local label=$1 want=$2 pattern=$3 out rc=0
  shift 3
  out="$("$@" 2>&1 </dev/null)" || rc=$?
  if [[ "$rc" -eq "$want" ]] && grep -Eq -- "$pattern" <<<"$out"; then
    ok "$label"
  else
    bad "$label (rc=$rc want $want, pattern $pattern)" "$out"
  fi
}

d="$(stage)"
expect "9 assets + SHA256SUMS -> 9/9" 0 "^release-assets: 9/9 present \(version $v\)$" "$verify" "$d" "$v"
# The release body tells users to run `shasum -a 256 -c SHA256SUMS`; prove that works.
if [[ "$(wc -l <"$d/SHA256SUMS" | tr -d ' ')" == 8 ]] && (cd "$d" && shasum -a 256 -c SHA256SUMS >/dev/null); then
  ok "SHA256SUMS has 8 lines and passes shasum -a 256 -c"
else
  bad "SHA256SUMS has 8 lines and passes shasum -a 256 -c" "$(cat "$d/SHA256SUMS")"
fi

d="$(stage)"
rm "$d/cockpit_${v}_x64.dmg"
expect "drop x64 dmg -> 8/9" 1 "^release-assets: 8/9 present .*
release-assets: FAIL missing: \*_x64\.dmg" "$verify" "$d" "$v"

d="$(stage)"
cp "$d/cockpit_${v}_amd64.AppImage" "$d/cockpit_${v}-copy_amd64.AppImage"
expect "duplicate AppImage -> fail" 1 "FAIL duplicate: \*_amd64\.AppImage matches 2 files" "$verify" "$d" "$v"

d="$(stage)"
printf 'tampered\n' >>"$d/cockpit-$v-web.tar.gz"
expect "asset changed after SHA256SUMS -> fail" 1 "FAIL sha256 mismatch: cockpit-$v-web\.tar\.gz" "$verify" "$d" "$v"

d="$(stage)"
python3 - "$d/SHA256SUMS" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().splitlines()
h, name = lines[0].split("  ", 1)
lines[0] = ("0" if h[0] != "0" else "1") + h[1:] + "  " + name
open(p, "w").write("\n".join(lines) + "\n")
PY
expect "tampered SHA256SUMS digest -> fail" 1 "FAIL sha256 mismatch: " "$verify" "$d" "$v"

d="$(stage)"
python3 - "$d/SHA256SUMS" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().splitlines()
open(p, "w").write("\n".join(lines[1:]) + "\n")
PY
expect "SHA256SUMS missing an entry -> fail" 1 "FAIL SHA256SUMS does not list " "$verify" "$d" "$v"

d="$(stage)"
: >"$d/cockpit_${v}_aarch64.dmg"
expect "empty asset -> fail" 1 "FAIL empty: cockpit_${v}_aarch64\.dmg" "$verify" "$d" "$v"

d="$(stage)"
mv "$d/cockpit-$v-darwin-x64.tar.gz" "$d/cockpit-2.2.2-darwin-x64.tar.gz"
expect "asset from another version -> fail" 1 "FAIL wrong version: cockpit-2\.2\.2-darwin-x64\.tar\.gz" "$verify" "$d" "$v"

d="$(stage)"
printf 'x\n' >"$d/notes.txt"
expect "unexpected extra file -> fail" 1 "FAIL unexpected asset: notes\.txt" "$verify" "$d" "$v"

d="$(stage)"
rm "$d/SHA256SUMS"
expect "no SHA256SUMS -> 8/9" 1 "^release-assets: 8/9 present .*
release-assets: FAIL missing: SHA256SUMS" "$verify" "$d" "$v"

expect "--names-from-stdin 9 names -> 9/9" 0 "^release-assets: 9/9 present \(version $v\)$" \
  bash -c 'printf "%s\n" "$@" SHA256SUMS | "$0" --names-from-stdin 2.3.0-dev' "$verify" "${assets[@]}"
expect "--names-from-stdin 8 names -> 8/9" 1 "^release-assets: 8/9 present" \
  bash -c 'printf "%s\n" "$@" | "$0" --names-from-stdin 2.3.0-dev' "$verify" "${assets[@]}"

mkdir -p "$tmpdir/short"
printf 'x\n' >"$tmpdir/short/cockpit-$v-web.tar.gz"
expect "--write-sums refuses an incomplete set" 1 "FAIL missing: cockpit-\*-linux-x64\.tar\.gz" "$verify" --write-sums "$tmpdir/short"
[[ ! -e "$tmpdir/short/SHA256SUMS" ]] && ok "--write-sums leaves no partial SHA256SUMS" || bad "--write-sums leaves no partial SHA256SUMS"

expect "usage error -> 2" 2 "verify-release-assets.sh DIR VERSION" "$verify"

printf 'verify-release-assets tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
