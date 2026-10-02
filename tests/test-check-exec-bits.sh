#!/usr/bin/env bash
# scripts/check-exec-bits.sh against temp git repos whose modes are set in the
# index (update-index --cacheinfo), never by chmod: a shipped script committed
# 100644 must fail naming its path; allowlisted sourced libs may stay 100644.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
check="$repo_root/scripts/check-exec-bits.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid \
  GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

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

# fixture NAME "MODE PATH"... -> commits each PATH with MODE and checks it out.
fixture() {
  local dir="$tmpdir/$1" spec mode path blob
  shift
  git init -q "$dir"
  git -C "$dir" config core.fileMode true
  for spec in "$@"; do
    mode=${spec%% *} path=${spec#* }
    blob="$(printf '#!/usr/bin/env bash\necho %s\n' "$path" | git -C "$dir" hash-object -w --stdin)"
    git -C "$dir" update-index --add --cacheinfo "$mode,$blob,$path"
  done
  git -C "$dir" commit -q -m fixture
  git -C "$dir" checkout -q -- .
  printf '%s\n' "$dir"
}

base=(
  "100755 install.sh"
  "100755 scripts/release-bundle.sh"
  "100755 tests/test-x.sh"
  "100755 bin/cockpit"
  "100644 bin/cockpit-lib"
  "100644 bin/cockpit-portable-lib"
)

d="$(fixture good "${base[@]}")"
expect "all shipped scripts 100755 -> ok" 0 "^exec-bits: ok \(4 files 100755; 2 sourced libs allowlisted" "$check" --root "$d"

d="$(fixture drop "${base[@]}" "100644 scripts/x.sh")"
expect "scripts/x.sh committed 100644 -> 1 naming the path" 1 "^exec-bits: FAIL scripts/x\.sh is 100644 in git \(want 100755\)$" "$check" --root "$d"

d="$(fixture binlib "${base[@]}" "100644 bin/cockpit-new-tool")"
expect "non-allowlisted bin/* at 100644 -> 1" 1 "FAIL bin/cockpit-new-tool is 100644" "$check" --root "$d"

d="$(fixture nested "${base[@]}" "100644 scripts/sub/helper.txt" "100644 tests/fixtures/data.sh")"
expect "nested non-shipped paths are out of scope -> ok" 0 "^exec-bits: ok \(4 files" "$check" --root "$d"

d="$(fixture worktree "${base[@]}")"
# A checkout that lost the bit on disk (e.g. core.fileMode=false copy) is caught too.
cat "$d/scripts/release-bundle.sh" >"$d/rb.tmp"
mv "$d/rb.tmp" "$d/scripts/release-bundle.sh"
if [[ -x "$d/scripts/release-bundle.sh" ]]; then
  bad "fixture setup: a redirect-created file should not be executable"
else
  expect "100755 in git but not executable on disk -> 1" 1 "FAIL scripts/release-bundle\.sh is 100755 in git but not executable" "$check" --root "$d"
fi

mkdir -p "$tmpdir/plain"
expect "not a git worktree -> 2" 2 "exec-bits: FAIL" "$check" --root "$tmpdir/plain"

d="$(fixture empty "100755 README.sh")"
expect "no install.sh -> 2 (fail closed, nothing checked)" 2 "nothing to check" "$check" --root "$d"

expect "the real tree passes" 0 "^exec-bits: ok " "$check"

printf 'check-exec-bits tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
