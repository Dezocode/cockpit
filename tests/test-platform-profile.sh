#!/usr/bin/env bash
# Platform adapter labels must not change the desktop TUI contract.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../bin/cockpit-lib
source "$repo_root/bin/cockpit-lib"

fp_foot="$(printf '%s\n' \
  'comms=:foot:' \
  'ssh_client=' \
  'colorterm=truecolor' \
  'wayland=wayland-1' \
  'session_type=wayland' \
  'term_program=' \
  'lc_terminal=' \
  'terminal=' \
  'display=')"
[[ "$("$repo_root/bin/cockpit-profile" --classify-fp "$fp_foot")" == foot ]]

fp_xfce="$(printf '%s\n' \
  'comms=:xfce4-terminal:' \
  'ssh_client=' \
  'colorterm=' \
  'wayland=' \
  'session_type=x11' \
  'term_program=' \
  'lc_terminal=' \
  'terminal=xfce4-terminal' \
  'display=:5')"
[[ "$("$repo_root/bin/cockpit-profile" --classify-fp "$fp_xfce")" == generic-desktop ]]

fp_termius="$(printf '%s\n' \
  'comms=:sshd:' \
  'ssh_client=100.64.0.2 22 3333' \
  'colorterm=' \
  'wayland=' \
  'session_type=' \
  'term_program=Termius' \
  'lc_terminal=' \
  'terminal=' \
  'display=')"
[[ "$("$repo_root/bin/cockpit-profile" --classify-fp "$fp_termius")" == termius-ios ]]

cockpit_platform_is_desktop foot
cockpit_platform_is_desktop generic-desktop
cockpit_platform_is_desktop macos-terminal
! cockpit_platform_is_desktop termius-ios

printf '%s\n' 'Cockpit platform regression: PASS'
