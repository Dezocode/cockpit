#!/usr/bin/env bash
# Every legacy codex-cockpit-* name is an install-time symlink to the single
# dispatcher bin/cockpit-legacy-alias, and executing it really execs the
# canonical cockpit-* binary (proved with argv0-recording stubs, not just by
# checking that the canonical file exists). Sourced legacy libs must leave the
# caller's shell options untouched.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init legacy-alias

names_list="$repo_root/bin/cockpit-legacy-names.list"
lib_names=" codex-cockpit-lib codex-cockpit-auth-lib codex-cockpit-agent-lib "

# expected_canonical <legacy-name>: independent copy of the documented mapping.
expected_canonical() {
  case "$1" in
    codex-cockpit) printf 'cockpit-main' ;;
    codex-mermaid-watch) printf 'cockpit-mermaid-watch' ;;
    codex-cockpit-*) printf 'cockpit-%s' "${1#codex-cockpit-}" ;;
    *) return 1 ;;
  esac
}

# link_legacy_names <bindir>: same layout install.sh creates.
link_legacy_names() {
  local bindir=$1 n
  while IFS= read -r -u 3 n || [[ -n "$n" ]]; do
    n="${n//$'\r'/}"
    [[ -n "$n" && "$n" != \#* ]] || continue
    ln -sf cockpit-legacy-alias "$bindir/$n"
  done 3<"$names_list"
}

# 1) Real install tree (mirrors install.sh): canonical binaries + symlinks.
real_bin="$FIXTURE_TEST_ROOT/real/bin"
mkdir -p "$real_bin"
for cockpit_bin in "$repo_root"/bin/cockpit*; do
  [[ "$cockpit_bin" == *.list ]] && continue
  install -m 0755 "$cockpit_bin" "$real_bin/"
done
link_legacy_names "$real_bin"

# 2) Stub tree: the real dispatcher + one stub per canonical cockpit-* name
#    that records its argv0 and args, so we can prove what the symlink execs.
stub_bin="$FIXTURE_TEST_ROOT/stub/bin"
stub_log="$FIXTURE_TEST_ROOT/stub/argv.log"
mkdir -p "$stub_bin"
install -m 0755 "$repo_root/bin/cockpit-legacy-alias" "$stub_bin/cockpit-legacy-alias"
for cockpit_bin in "$repo_root"/bin/cockpit*; do
  base="${cockpit_bin##*/}"
  case "$base" in *.list|cockpit-legacy-alias) continue ;; esac
  printf '#!/usr/bin/env bash\nprintf "STUB argv0=%%s args=%%s\\n" "${0##*/}" "$*" >"%s"\n' \
    "$stub_log" >"$stub_bin/$base"
  chmod 0755 "$stub_bin/$base"
done
link_legacy_names "$stub_bin"

total=0 ok=0 fail=0
pass() { ok=$((ok + 1)); printf 'OK   %s\n' "$*"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$*"; }

while IFS= read -r -u 3 legacy_name || [[ -n "$legacy_name" ]]; do
  legacy_name="${legacy_name//$'\r'/}"
  [[ -n "$legacy_name" && "$legacy_name" != \#* ]] || continue
  total=$((total + 1))

  link="$real_bin/$legacy_name"
  if [[ ! -L "$link" || "$(readlink -- "$link")" != cockpit-legacy-alias ]]; then
    bad "$legacy_name: not a symlink to cockpit-legacy-alias"
    continue
  fi
  if ! canonical=$(expected_canonical "$legacy_name"); then
    bad "$legacy_name: unknown legacy name"
    continue
  fi
  if [[ ! -f "$real_bin/$canonical" ]]; then
    bad "$legacy_name: canonical $canonical missing from install tree"
    continue
  fi

  if [[ "$lib_names" == *" $legacy_name "* ]]; then
    # Sourced mode: canonical library loads through the symlink and the
    # caller's errexit/nounset/pipefail stay off (old shim behaviour).
    if out=$(bash --norc --noprofile -c '
        set +euo pipefail
        before="$-"
        source "$1" || exit 3
        type cockpit_config_home >/dev/null 2>&1 || exit 4
        [[ $- != *e* && $- != *u* ]] || exit 5
        [[ -z "$(set -o | awk "/^pipefail/ && \$2 == \"on\"")" ]] || exit 6
        [[ "$before" == "$-" ]] || exit 7
        printf "flags %s -> %s" "$before" "$-"' _ "$link" </dev/null 2>&1); then
      pass "$legacy_name -> $canonical (sourced; $out)"
    else
      bad "$legacy_name: sourced check rc=$? ${out:-}"
    fi
    continue
  fi

  # Exec mode: run the symlink in the stub tree and check the stub that ran.
  rm -f "$stub_log"
  "$stub_bin/$legacy_name" --legacy-alias-probe "arg two" </dev/null >/dev/null 2>&1 || true
  want="STUB argv0=$canonical args=--legacy-alias-probe arg two"
  got=$(cat "$stub_log" 2>/dev/null || true)
  if [[ "$got" == "$want" ]]; then
    pass "$legacy_name -> $canonical (exec via dispatcher; $got)"
  else
    bad "$legacy_name: expected '$want', got '${got:-<nothing ran>}'"
  fi
done 3<"$names_list"

printf 'legacy-alias: %d/%d OK, %d failed\n' "$ok" "$total" "$fail"
[[ "$total" -gt 0 && "$fail" -eq 0 ]]
