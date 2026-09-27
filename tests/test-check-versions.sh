#!/usr/bin/env bash
# scripts/check-versions.sh + scripts/set-version.sh against fixture copies of
# the real manifests: each named drift must exit 1 with its own message.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
check="$repo_root/scripts/check-versions.sh"
setv="$repo_root/scripts/set-version.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

files=(app/package.json app/pnpm-lock.yaml app/src-tauri/Cargo.toml app/src-tauri/Cargo.lock app/src-tauri/tauri.conf.json)
n=0
fixture() {
  n=$((n + 1))
  local dir="$tmpdir/f$n" f
  for f in "${files[@]}"; do
    mkdir -p "$dir/$(dirname "$f")"
    cp "$repo_root/$f" "$dir/$f"
  done
  printf '%s\n' "$dir"
}

pass=0 fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n%s\n' "$1" "${2:-}"; fail=$((fail + 1)); }

# expect LABEL RC PATTERN CMD... : exit code must equal RC and output match PATTERN.
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

# replace FILE FROM TO: literal one-shot edit of a fixture copy.
replace() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
if old not in text:
    sys.exit(f"replace: {old!r} not in {path}")
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
}

version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$repo_root/app/package.json")"

d="$(fixture)"
expect "a: equal manifests -> 0" 0 "^versions: ok ${version//./\\.} \(app/package.json = " "$check" --root "$d"

d="$(fixture)"
replace "$d/app/src-tauri/Cargo.lock" "name = \"cockpit\"
version = \"$version\"" "name = \"cockpit\"
version = \"0.0.1\""
expect "b: Cargo.lock root drift -> 1" 1 "FAIL app/src-tauri/Cargo.lock cockpit version '0.0.1'" "$check" --root "$d"

d="$(fixture)"
replace "$d/app/src-tauri/tauri.conf.json" '"version": "../package.json"' "\"version\": \"$version\""
expect "c: tauri.conf literal version -> 1" 1 'FAIL app/src-tauri/tauri.conf.json version .* must be "\.\./package\.json"' "$check" --root "$d"

d="$(fixture)"
expect "d: --tag v9.9.9 -> 1" 1 "FAIL tag v9\.9\.9 != v${version//./\\.}" "$check" --root "$d" --tag v9.9.9
expect "d2: GITHUB_REF_NAME=v9.9.9 -> 1" 1 "FAIL tag v9\.9\.9 != " env GITHUB_REF_TYPE= GITHUB_REF_NAME=v9.9.9 "$check" --root "$d"
expect "d3: tag ref without v prefix -> 1" 1 "FAIL tag '9\.9\.9' must start with 'v'" env GITHUB_REF_TYPE=tag GITHUB_REF_NAME=9.9.9 "$check" --root "$d"

d="$(fixture)"
expect "e: --tag v$version -> 0" 0 "^versions: .*; tag v${version//./\\.}$" "$check" --root "$d" --tag "v$version"
expect "e2: branch ref named like a tag is not a tag -> 0" 0 "^versions: ok " env GITHUB_REF_TYPE=branch GITHUB_REF_NAME=v9.9.9 "$check" --root "$d"

d="$(fixture)"
replace "$d/app/src-tauri/Cargo.toml" "version = \"$version\"" 'version = "0.0.2"'
expect "f: Cargo.toml drift -> 1" 1 "FAIL app/src-tauri/Cargo.toml \[package\] version '0.0.2'" "$check" --root "$d"

d="$(fixture)"
replace "$d/app/pnpm-lock.yaml" "'@tauri-apps/api':
        specifier: 2.11.1
        version: 2.11.1" "'@tauri-apps/api':
        specifier: 2.11.1
        version: 2.10.1"
expect "g: tauri crate vs @tauri-apps/api minor mismatch -> 1" 1 'FAIL tauri 2\.11\.[0-9]+ and @tauri-apps/api 2\.10\.1 differ in major\.minor' "$check" --root "$d"

d="$(fixture)"
replace "$d/app/pnpm-lock.yaml" "'@tauri-apps/plugin-opener':
        specifier: ^2.3.0
        version: 2.5.5" "'@tauri-apps/plugin-opener':
        specifier: ^2.3.0
        version: 2.4.0"
expect "h: tauri-plugin-opener vs @tauri-apps/plugin-opener mismatch -> 1" 1 'FAIL tauri-plugin-opener 2\.5\.[0-9]+ and @tauri-apps/plugin-opener 2\.4\.0 differ' "$check" --root "$d"

d="$(fixture)"
replace "$d/app/package.json" "\"version\": \"$version\"" '"version": "two"'
expect "i: non-semver package version -> 1" 1 "FAIL app/package.json version 'two' is not semver" "$check" --root "$d"

# py3.9 path (no tomllib, e.g. macOS /usr/bin/python3): same verdicts.
mkdir -p "$tmpdir/notomllib"
printf 'raise ModuleNotFoundError("no tomllib")\n' >"$tmpdir/notomllib/tomllib.py"
d="$(fixture)"
expect "j: no-tomllib parser, equal -> 0" 0 "^versions: ok " env PYTHONPATH="$tmpdir/notomllib" "$check" --root "$d"
replace "$d/app/src-tauri/Cargo.lock" "name = \"cockpit\"
version = \"$version\"" "name = \"cockpit\"
version = \"0.0.1\""
expect "j2: no-tomllib parser, Cargo.lock drift -> 1" 1 "FAIL app/src-tauri/Cargo.lock cockpit version '0.0.1'" env PYTHONPATH="$tmpdir/notomllib" "$check" --root "$d"

# set-version rewrites all three manifests; tauri.conf follows by reference.
d="$(fixture)"
expect "k: set-version 9.9.9-rc.1 -> check ok" 0 "^versions: ok 9\.9\.9-rc\.1 " "$setv" --root "$d" 9.9.9-rc.1
expect "k2: after set-version, --tag v9.9.9-rc.1 -> 0" 0 "tag v9\.9\.9-rc\.1$" "$check" --root "$d" --tag v9.9.9-rc.1
if grep -q '"version": "../package.json"' "$d/app/src-tauri/tauri.conf.json"; then
  ok "k3: set-version leaves tauri.conf by reference"
else
  bad "k3: set-version leaves tauri.conf by reference"
fi
expect "l: set-version rejects a non-version -> 2" 2 "is not X\.Y\.Z" "$setv" --root "$d" 'v1;rm'

printf 'check-versions tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
