#!/usr/bin/env bash
# Every legacy codex-cockpit-* name dispatches to the canonical cockpit-* binary.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init legacy-alias

install_root="$FIXTURE_TEST_ROOT/install"
mkdir -p "$install_root/bin"
for cockpit_bin in "$repo_root"/bin/cockpit*; do
  [[ "$cockpit_bin" == *.list ]] && continue
  cp -a "$cockpit_bin" "$install_root/bin/"
done
cp "$repo_root/bin/cockpit-legacy-alias" "$install_root/bin/cockpit-legacy-alias"
chmod +x "$install_root/bin/"*
while IFS= read -r legacy_name || [[ -n "$legacy_name" ]]; do
  legacy_name="${legacy_name//$'\r'/}"
  [[ -n "$legacy_name" ]] || continue
  ln -sf cockpit-legacy-alias "$install_root/bin/$legacy_name"
done <"$repo_root/bin/cockpit-legacy-names.list"

export PATH="$install_root/bin:$PATH"

fail=0
while IFS= read -r legacy_name || [[ -n "$legacy_name" ]]; do
  legacy_name="${legacy_name//$'\r'/}"
  [[ -n "$legacy_name" ]] || continue
  case "$legacy_name" in
    codex-cockpit-lib|codex-cockpit-auth-lib|codex-cockpit-agent-lib)
      if ! bash -c "source $(printf %q "$install_root/bin/$legacy_name") && type cockpit_config_home >/dev/null"; then
        printf 'FAIL lib source: %s\n' "$legacy_name"
        fail=1
      else
        printf 'OK lib source: %s\n' "$legacy_name"
      fi
      continue
      ;;
    codex-cockpit-client)
      target=$("$install_root/bin/$legacy_name" --help 2>&1 || true)
      if [[ -x "$install_root/bin/cockpit-client" ]]; then
        printf 'OK dispatch: %s → cockpit-client\n' "$legacy_name"
      else
        printf 'FAIL: missing cockpit-client for %s\n' "$legacy_name"
        fail=1
      fi
      continue
      ;;
  esac
  canonical="cockpit-${legacy_name#codex-cockpit-}"
  [[ "$legacy_name" == codex-cockpit ]] && canonical=cockpit-main
  [[ "$legacy_name" == codex-mermaid-watch ]] && canonical=cockpit-mermaid-watch
  if [[ ! -x "$install_root/bin/$canonical" ]]; then
    printf 'FAIL missing canonical %s for legacy %s\n' "$canonical" "$legacy_name"
    fail=1
    continue
  fi
  resolved=$("$install_root/bin/$legacy_name" --help 2>&1 | head -1 || true)
  printf 'OK dispatch: %s → %s (%s)\n' "$legacy_name" "$canonical" "${resolved:-ran}"
done <"$repo_root/bin/cockpit-legacy-names.list"

exit "$fail"
