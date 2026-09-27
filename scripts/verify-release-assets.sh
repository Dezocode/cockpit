#!/usr/bin/env bash
# Release asset contract (9 assets). Each pattern must match exactly one file;
# every name except SHA256SUMS carries the version; files must be non-empty and
# SHA256SUMS must list exactly the 8 other assets with matching digests.
#
#   verify-release-assets.sh DIR VERSION            verify a staged asset dir
#   verify-release-assets.sh --write-sums DIR       write DIR/SHA256SUMS (8 assets)
#   verify-release-assets.sh --names-from-stdin V   verify published names only
#
# Exit: 0 ok, 1 contract broken, 2 usage.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bin/cockpit-portable-lib
source "$root/bin/cockpit-portable-lib"

patterns=(
  'cockpit-*-linux-x64.tar.gz'
  'cockpit-*-web.tar.gz'
  'cockpit-*-darwin-arm64.tar.gz'
  'cockpit-*-darwin-x64.tar.gz'
  '*_amd64.deb'
  '*_amd64.AppImage'
  '*_aarch64.dmg'
  '*_x64.dmg'
  'SHA256SUMS'
)
total=${#patterns[@]}

usage() {
  sed -n '6,8s/^# \{0,3\}//p' "$0" >&2
  exit 2
}

# match_names VERSION NAME... -> sets present, problems[], matched[] (index-aligned)
problems=()
matched=()
present=0
match_names() {
  local version=$1 i pat name hits hit_name
  shift
  local names=("$@")
  for ((i = 0; i < total; i++)); do
    pat=${patterns[i]}
    hits=0 hit_name=""
    for name in ${names[@]+"${names[@]}"}; do
      # shellcheck disable=SC2053 # $pat is a glob on purpose
      if [[ "$name" == $pat ]]; then
        hits=$((hits + 1))
        hit_name=$name
      fi
    done
    matched[i]=""
    if ((hits == 0)); then
      problems+=("missing: $pat")
    elif ((hits > 1)); then
      problems+=("duplicate: $pat matches $hits files")
    elif [[ "$pat" != SHA256SUMS && "$hit_name" != *"$version"* ]]; then
      problems+=("wrong version: $hit_name (want $version)")
    else
      matched[i]=$hit_name
      present=$((present + 1))
    fi
  done
  for name in ${names[@]+"${names[@]}"}; do
    local known=0
    for pat in "${patterns[@]}"; do
      # shellcheck disable=SC2053
      [[ "$name" == $pat ]] && known=1
    done
    ((known)) || problems+=("unexpected asset: $name")
  done
}

finish() {
  local version=$1 p
  printf 'release-assets: %s/%s present (version %s)\n' "$present" "$total" "$version"
  for p in ${problems[@]+"${problems[@]}"}; do
    printf 'release-assets: FAIL %s\n' "$p"
  done
  if ((present != total || ${#problems[@]} > 0)); then
    exit 1
  fi
}

list_dir() {
  local dir=$1 f
  names=()
  for f in "$dir"/* "$dir"/.[!.]*; do
    [[ -e "$f" || -L "$f" ]] || continue
    names+=("${f##*/}")
  done
}

sha_of() {
  local digest
  digest="$(cockpit_sha256 "$1")"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 1
  printf '%s\n' "$digest"
}

case "${1:-}" in
  --write-sums)
    [[ $# -eq 2 && -d "$2" ]] || usage
    dir=$2
    list_dir "$dir"
    sums=()
    for name in ${names[@]+"${names[@]}"}; do
      [[ "$name" == SHA256SUMS ]] || sums+=("$name")
    done
    match_names "" ${sums[@]+"${sums[@]}"}
    tmp="$(mktemp "$dir/.SHA256SUMS.XXXXXX")"
    for ((i = 0; i < total - 1; i++)); do
      [[ -n "${matched[i]}" ]] || continue
      if ! digest="$(sha_of "$dir/${matched[i]}")"; then
        problems+=("cannot hash ${matched[i]}")
        continue
      fi
      printf '%s  %s\n' "$digest" "${matched[i]}" >>"$tmp"
    done
    # SHA256SUMS itself is written here, so only the 8 hashed assets count.
    clean=()
    for p in ${problems[@]+"${problems[@]}"}; do
      [[ "$p" == "missing: SHA256SUMS" ]] || clean+=("$p")
    done
    if ((${#clean[@]} > 0)); then
      rm -f "$tmp"
      for p in "${clean[@]}"; do printf 'release-assets: FAIL %s\n' "$p"; done
      exit 1
    fi
    LC_ALL=C sort -k2 "$tmp" >"$dir/SHA256SUMS"
    rm -f "$tmp"
    printf 'release-assets: wrote %s/SHA256SUMS (%s entries)\n' "$dir" "$(wc -l <"$dir/SHA256SUMS" | tr -d ' ')"
    ;;
  --names-from-stdin)
    [[ $# -eq 2 && -n "$2" ]] || usage
    version=$2
    names=()
    while IFS= read -r name || [[ -n "$name" ]]; do
      [[ -n "$name" ]] && names+=("$name")
    done
    match_names "$version" ${names[@]+"${names[@]}"}
    finish "$version"
    ;;
  -*|"")
    usage
    ;;
  *)
    [[ $# -eq 2 && -d "$1" && -n "$2" ]] || usage
    dir=$1 version=$2
    list_dir "$dir"
    match_names "$version" ${names[@]+"${names[@]}"}
    for ((i = 0; i < total; i++)); do
      name=${matched[i]}
      [[ -n "$name" ]] || continue
      if [[ ! -f "$dir/$name" || -L "$dir/$name" ]]; then
        problems+=("not a regular file: $name")
      elif [[ ! -s "$dir/$name" ]]; then
        problems+=("empty: $name")
      fi
    done
    sums_file="$dir/${matched[total - 1]:-SHA256SUMS}"
    if [[ -f "$sums_file" && -s "$sums_file" ]]; then
      listed=()
      while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue
        if ! [[ "$line" =~ ^([0-9a-f]{64})\ [\ *](.+)$ ]]; then
          problems+=("SHA256SUMS malformed line: $line")
          continue
        fi
        want=${BASH_REMATCH[1]} file=${BASH_REMATCH[2]}
        for seen in ${listed[@]+"${listed[@]}"}; do
          [[ "$seen" == "$file" ]] && problems+=("SHA256SUMS lists $file twice")
        done
        listed+=("$file")
        if [[ "$file" == */* || ! -f "$dir/$file" ]]; then
          problems+=("SHA256SUMS lists a file that is not an asset: $file")
          continue
        fi
        if ! got="$(sha_of "$dir/$file")"; then
          problems+=("cannot hash $file")
        elif [[ "$got" != "$want" ]]; then
          problems+=("sha256 mismatch: $file")
        fi
      done <"$sums_file"
      for ((i = 0; i < total - 1; i++)); do
        name=${matched[i]}
        [[ -n "$name" ]] || continue
        hit=0
        for seen in ${listed[@]+"${listed[@]}"}; do
          [[ "$seen" == "$name" ]] && hit=1
        done
        ((hit)) || problems+=("SHA256SUMS does not list $name")
      done
      for seen in ${listed[@]+"${listed[@]}"}; do
        [[ "$seen" == SHA256SUMS ]] && problems+=("SHA256SUMS lists itself")
      done
    fi
    finish "$version"
    printf 'release-assets: SHA256SUMS verified (%s entries)\n' "$((total - 1))"
    ;;
esac
