#!/usr/bin/env bash
# Fresh-HOME install: a login bash (`bash -lc`, macOS Terminal, ssh) must find
# cockpit. cockpit_rc_write wires ~/.bashrc into whichever login file bash reads
# first, once, with a POSIX line; existing loaders are left alone.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

pass=0 fail=0
ok() { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n%s\n' "$1" "${2:-}"; fail=$((fail + 1)); }

install_into() {
  (
    export HOME="$1" SHELL=/bin/bash PATH="/usr/local/bin:/usr/bin:/bin"
    export COCKPIT_INSTALL_WEB_BUILD=0 COCKPIT_INSTALL_SERVICE=0
    unset COCKPIT_SHELL_RC XDG_CONFIG_HOME ZDOTDIR COCKPIT_INSTALL_HOSTINGER
    /bin/bash "$repo_root/install.sh" </dev/null >"$1.install.log" 2>&1
  )
}
login_path() {
  HOME="$1" PATH="/usr/local/bin:/usr/bin:/bin" bash -lc 'command -v cockpit' </dev/null 2>/dev/null | tail -n 1 || :
}
loader_count() {
  grep -c 'Cockpit: login shell loads' "$1" 2>/dev/null || :
}

h="$tmpdir/fresh"
mkdir -p "$h"
install_into "$h" || bad "fresh: install" "$(tail -20 "$h.install.log")"
install_into "$h" || bad "fresh: reinstall" "$(tail -20 "$h.install.log")"
got="$(login_path "$h")"
[[ "$got" == "$h/.local/bin/cockpit" ]] && ok "fresh HOME: bash -lc finds cockpit" || bad "fresh HOME: bash -lc finds cockpit (got '$got')"
[[ "$(loader_count "$h/.bash_profile")" == 1 ]] && ok "fresh HOME: one loader line in new ~/.bash_profile after reinstall" ||
  bad "fresh HOME: one loader line in new ~/.bash_profile after reinstall" "$(cat "$h/.bash_profile" 2>&1)"

# Ubuntu /etc/skel style: ~/.profile already loads ~/.bashrc; nothing is added
# and no ~/.bash_profile appears (it would shadow ~/.profile).
h="$tmpdir/skel"
mkdir -p "$h"
printf 'if [ -n "$BASH_VERSION" ]; then\n    if [ -f "$HOME/.bashrc" ]; then\n\t. "$HOME/.bashrc"\n    fi\nfi\n' >"$h/.profile"
cp "$h/.profile" "$tmpdir/skel.profile.orig"
install_into "$h" || bad "skel: install" "$(tail -20 "$h.install.log")"
cmp -s "$h/.profile" "$tmpdir/skel.profile.orig" && ok "skel ~/.profile that sources ~/.bashrc is untouched" || bad "skel ~/.profile that sources ~/.bashrc is untouched" "$(cat "$h/.profile")"
[[ ! -e "$h/.bash_profile" ]] && ok "skel: no ~/.bash_profile created" || bad "skel: no ~/.bash_profile created"
got="$(login_path "$h")"
[[ "$got" == "$h/.local/bin/cockpit" ]] && ok "skel: bash -lc finds cockpit" || bad "skel: bash -lc finds cockpit (got '$got')"

# ~/.profile without a loader (and no ~/.bash_profile): the loader goes into
# ~/.profile, stays valid for sh, and is not duplicated on reinstall.
h="$tmpdir/profile-only"
mkdir -p "$h"
printf 'export EDITOR=vi\n' >"$h/.profile"
install_into "$h" && install_into "$h" || bad "profile-only: install" "$(tail -20 "$h.install.log")"
[[ ! -e "$h/.bash_profile" && "$(loader_count "$h/.profile")" == 1 ]] && ok "profile-only: one loader appended to ~/.profile" ||
  bad "profile-only: one loader appended to ~/.profile" "$(cat "$h/.profile")"
if out="$(HOME="$h" /bin/sh -c '. "$HOME/.profile" && echo sourced' 2>&1)" && [[ "$out" == sourced ]]; then
  ok "profile-only: sh can still source ~/.profile"
else
  bad "profile-only: sh can still source ~/.profile" "$out"
fi
got="$(login_path "$h")"
[[ "$got" == "$h/.local/bin/cockpit" ]] && ok "profile-only: bash -lc finds cockpit" || bad "profile-only: bash -lc finds cockpit (got '$got')"

# ~/.bash_profile that already sources ~/.bashrc: untouched.
h="$tmpdir/has-loader"
mkdir -p "$h"
printf '[ -f ~/.bashrc ] && source ~/.bashrc\n' >"$h/.bash_profile"
cp "$h/.bash_profile" "$tmpdir/has-loader.orig"
install_into "$h" || bad "has-loader: install" "$(tail -20 "$h.install.log")"
cmp -s "$h/.bash_profile" "$tmpdir/has-loader.orig" && ok "existing ~/.bash_profile loader is untouched" || bad "existing ~/.bash_profile loader is untouched" "$(cat "$h/.bash_profile")"

printf 'rc-login-shell tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
