#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
unset COCKPIT_SHELL_RC COCKPIT_INSTALL_HOSTINGER COCKPIT_INSTALL_SERVICE
fail() {
  printf 'install-shells: FAIL (%s)\n' "$1"
  exit 1
}

run_install() {
  local shell_name=$1
  local home=$2
  (
    export HOME="$home" SHELL="/bin/$shell_name" PATH="/usr/local/bin:/usr/bin:/bin"
    export COCKPIT_INSTALL_WEB_BUILD=0 COCKPIT_INSTALL_SERVICE=0 COCKPIT_INSTALL_HOSTINGER=0
    unset COCKPIT_SHELL_RC
    /bin/bash "$repo_root/install.sh" </dev/null >/dev/null 2>&1
  ) || return 1
}

count_markers() {
  local file=$1
  grep -c '# >>> cockpit >>>' "$file" 2>/dev/null || echo 0
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
fakebin="$tmpdir/fakebin"
sentinel="$tmpdir/sentinel"
mkdir -p "$fakebin"
printf '#!/bin/sh\necho hit >>%s\n' "$sentinel" >"$fakebin/useradd"
printf '#!/bin/sh\necho hit >>%s\n' "$sentinel" >"$fakebin/systemctl"
chmod +x "$fakebin/useradd" "$fakebin/systemctl"

for shell in bash zsh fish; do
  command -v "$shell" >/dev/null 2>&1 || continue
  home="$tmpdir/home-$shell"
  mkdir -p "$home"
  unset COCKPIT_SHELL_RC
  run_install "$shell" "$home" || fail "install $shell"
  run_install "$shell" "$home" || fail "install $shell retry"
  case "$shell" in
    bash)
      rcfile="$home/.bashrc"
      count="$(count_markers "$rcfile")"
      [[ "$count" == 1 ]] || fail "bash marker count"
      path="$(HOME="$home" bash -ic 'command -v cockpit' 2>/dev/null | tail -1)"
      [[ "$path" == "$home/.local/bin/cockpit" ]] || fail "bash cockpit path"
      ;;
    zsh)
      rcfile="$home/.zshrc"
      count="$(count_markers "$rcfile")"
      [[ "$count" == 1 ]] || fail "zsh marker count"
      path="$(HOME="$home" zsh -ic 'command -v cockpit' 2>/dev/null | tail -1)"
      [[ "$path" == "$home/.local/bin/cockpit" ]] || fail "zsh cockpit path"
      ;;
    fish)
      rcfile="$home/.config/fish/conf.d/cockpit.fish"
      [[ -f "$rcfile" ]] || fail "fish drop-in"
      path="$(HOME="$home" fish -c 'command -v cockpit' 2>/dev/null | tail -1)"
      [[ "$path" == "$home/.local/bin/cockpit" ]] || fail "fish cockpit path"
      ;;
  esac
done

override_home="$tmpdir/home-override"
mkdir -p "$override_home"
override_rc="$override_home/custom.rc"
touch "$override_rc"
HOME="$override_home" COCKPIT_SHELL_RC="$override_rc" SHELL=/bin/bash \
  /bin/bash "$repo_root/install.sh" </dev/null >/dev/null 2>&1
grep -q '# >>> cockpit >>>' "$override_rc" || fail "COCKPIT_SHELL_RC"

legacy_home="$tmpdir/home-legacy"
mkdir -p "$legacy_home"
printf '\n# Cockpit PATH\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$legacy_home/.bashrc"
HOME="$legacy_home" SHELL=/bin/bash /bin/bash "$repo_root/install.sh" </dev/null >/dev/null 2>&1
grep -q '# Cockpit PATH' "$legacy_home/.bashrc" && fail "legacy PATH block"
grep -q '# >>> cockpit >>>' "$legacy_home/.bashrc" || fail "legacy migration"

if [[ "$(uname -s)" == Darwin ]]; then
  rm -f "$sentinel"
  mkdir -p "$tmpdir/home-darwin"
  PATH="$fakebin:$PATH" HOME="$tmpdir/home-darwin" COCKPIT_INSTALL_SERVICE=1 SHELL=/bin/bash \
    /bin/bash "$repo_root/install.sh" </dev/null >/dev/null 2>&1
  [[ ! -e "$sentinel" ]] || fail "darwin systemd sentinel"
fi

bash3_major="$(/bin/bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null || echo 5)"
if [[ "$bash3_major" -lt 4 ]]; then
  set +e
  out="$(COCKPIT_BASH4_CANDIDATES=/nonexistent PATH="$repo_root/bin:$PATH" /bin/bash "$repo_root/bin/cockpit" -h 2>&1)"
  rc=$?
  set -e
  [[ "$rc" == 64 ]] || fail "bash3 hint rc"
  grep -q 'bash >= 4 required' <<<"$out" || fail "bash3 hint text"
fi

if command -v /opt/homebrew/bin/bash >/dev/null 2>&1 ||
  command -v /usr/local/bin/bash >/dev/null 2>&1; then
  set +e
  PATH="$repo_root/bin:$PATH" /bin/bash "$repo_root/bin/cockpit" -h >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" == 0 ]] || fail "brew bash cockpit -h"
fi

printf 'install-shells: ok (bash zsh fish)\n'
