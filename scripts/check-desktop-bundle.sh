#!/usr/bin/env bash
# Integrity of a native Tauri bundle built on this runner (never cross-built):
#   Linux : one *_amd64.deb (Package cockpit, Version = app version, ships
#           usr/bin/cockpit) + one *_amd64.AppImage whose --appimage-extract
#           yields an executable x86-64 usr/bin/cockpit.
#   macOS : one *_<aarch64|x64>.dmg for this runner's arch; mounted read-only,
#           cockpit.app/Contents/MacOS/cockpit is executable, ad-hoc signed, and
#           `lipo -archs` equals the runner arch; detached on exit.
#   check-desktop-bundle.sh [--collect DIR]   (DIR receives the checked assets)
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bundle="${COCKPIT_BUNDLE_DIR:-$root/app/src-tauri/target/release/bundle}"
collect=""
if [[ "${1:-}" == --collect ]]; then
  [[ $# -eq 2 ]] || { echo "usage: ${0##*/} [--collect DIR]" >&2; exit 2; }
  collect=$2
  mkdir -p "$collect"
elif [[ $# -gt 0 ]]; then
  echo "usage: ${0##*/} [--collect DIR]" >&2
  exit 2
fi

version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$root/app/package.json")"
work="$(mktemp -d)"
mnt=""
cleanup() {
  if [[ -n "$mnt" ]]; then
    hdiutil detach "$mnt" -quiet 2>/dev/null || hdiutil detach "$mnt" -force -quiet 2>/dev/null || :
  fi
  rm -rf "$work"
}
trap cleanup EXIT

fail() {
  printf 'desktop-bundle: FAIL %s\n' "$*"
  exit 1
}
# one GLOB: exactly one match, echoed.
one() {
  local matches=() f
  for f in $1; do
    [[ -e "$f" ]] && matches+=("$f")
  done
  [[ ${#matches[@]} -eq 1 ]] || fail "want exactly one $1, found ${#matches[@]}: ${matches[*]-}"
  printf '%s\n' "${matches[0]}"
}
size_of() { wc -c <"$1" | tr -d ' '; }
report() {
  local f=$1
  printf 'desktop-bundle: asset %s %s bytes\n' "${f##*/}" "$(size_of "$f")"
  [[ -z "$collect" ]] || cp -p "$f" "$collect/"
}

printf 'desktop-bundle: %s %s, app version %s, bundle dir %s\n' "$(uname -s)" "$(uname -m)" "$version" "$bundle"
case "$(uname -s)" in
  Linux)
    [[ "$(uname -m)" == x86_64 ]] || fail "linux bundles are published for x86_64 only (runner is $(uname -m))"
    deb="$(one "$bundle/deb/*_amd64.deb")"
    appimage="$(one "$bundle/appimage/*_amd64.AppImage")"
    [[ "${deb##*/}" == *"_${version}_"* ]] || fail "deb name ${deb##*/} lacks _${version}_"
    [[ "${appimage##*/}" == *"_${version}_"* ]] || fail "AppImage name ${appimage##*/} lacks _${version}_"
    deb_version="$(dpkg-deb -f "$deb" Version)"
    deb_package="$(dpkg-deb -f "$deb" Package)"
    deb_arch="$(dpkg-deb -f "$deb" Architecture)"
    printf 'desktop-bundle: dpkg-deb -f %s Version = %s (Package %s, Architecture %s)\n' "${deb##*/}" "$deb_version" "$deb_package" "$deb_arch"
    [[ "$deb_version" == "$version" ]] || fail "deb Version $deb_version != $version"
    [[ "$deb_package" == cockpit && "$deb_arch" == amd64 ]] || fail "deb Package/Architecture $deb_package/$deb_arch"
    dpkg-deb -c "$deb" | grep -Eq '[[:space:]]\./usr/bin/cockpit$' || fail "deb does not ship ./usr/bin/cockpit"
    [[ -x "$appimage" ]] || fail "AppImage is not executable as built: $appimage"
    (cd "$work" && "$appimage" --appimage-extract >/dev/null) || fail "AppImage --appimage-extract failed"
    bin="$work/squashfs-root/usr/bin/cockpit"
    [[ -x "$bin" ]] || fail "AppImage payload has no executable usr/bin/cockpit"
    file_out="$(file -b "$bin")"
    printf 'desktop-bundle: AppImage --appimage-extract -> squashfs-root/usr/bin/cockpit (%s)\n' "${file_out%%,*}"
    [[ "$file_out" == *x86-64* ]] || fail "AppImage binary is not x86-64: $file_out"
    report "$deb"
    report "$appimage"
    ;;
  Darwin)
    case "$(uname -m)" in
      arm64) dmg_arch=aarch64 lipo_arch=arm64 ;;
      x86_64) dmg_arch=x64 lipo_arch=x86_64 ;;
      *) fail "unsupported mac arch $(uname -m)" ;;
    esac
    dmg="$(one "$bundle/dmg/*_${dmg_arch}.dmg")"
    [[ "${dmg##*/}" == *"_${version}_${dmg_arch}.dmg" ]] || fail "dmg name ${dmg##*/} lacks _${version}_${dmg_arch}"
    mnt="$work/mnt"
    mkdir -p "$mnt"
    hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$dmg" >/dev/null || { mnt=""; fail "hdiutil attach failed: $dmg"; }
    printf 'desktop-bundle: hdiutil attach -nobrowse -readonly %s -> %s\n' "${dmg##*/}" "$mnt"
    app="$mnt/cockpit.app"
    bin="$app/Contents/MacOS/cockpit"
    test -x "$bin" || fail "not executable: cockpit.app/Contents/MacOS/cockpit in ${dmg##*/}"
    printf 'desktop-bundle: test -x cockpit.app/Contents/MacOS/cockpit -> ok\n'
    sig="$(codesign -dv "$app" 2>&1 || :)"
    printf '%s\n' "$sig" | grep -E '^(Identifier|Format|Signature|TeamIdentifier)=' | sed 's/^/desktop-bundle: codesign -dv: /'
    grep -q '^Signature=adhoc$' <<<"$sig" || fail "cockpit.app is not ad-hoc signed"
    codesign --verify --deep --strict "$app" || fail "codesign --verify failed"
    archs="$(lipo -archs "$bin")"
    printf 'desktop-bundle: lipo -archs cockpit = %s (runner %s)\n' "$archs" "$(uname -m)"
    [[ "$archs" == "$lipo_arch" ]] || fail "binary archs '$archs' != native $lipo_arch"
    short="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
    printf 'desktop-bundle: CFBundleShortVersionString = %s\n' "$short"
    hdiutil detach "$mnt" -quiet
    mnt=""
    report "$dmg"
    ;;
  *)
    fail "unsupported OS $(uname -s)"
    ;;
esac
printf 'desktop-bundle: ok\n'
