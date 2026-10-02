#!/usr/bin/env bash
# get-cockpit.sh — one-command Cockpit bootstrap (checksum-verified when downloading a release).
# Bash-3.2-safe. Inline sha256sum/shasum is the ONE sanctioned copy outside bin/cockpit-portable-lib.
set -euo pipefail

VERSION="${COCKPIT_VERSION:-latest}"
FROM_DIR=""
FROM_SOURCE=""
DO_FROM_SOURCE=0
REPO_URL="${COCKPIT_REPO_URL:-https://github.com/Dezocode/cockpit}"
RELEASE_BASE="${COCKPIT_RELEASE_BASE:-https://github.com/Dezocode/cockpit/releases}"

usage() {
  cat <<'U'
Usage: get-cockpit.sh [--from-dir DIR | --from-source [REF]] [--version V]
U
}

while [ $# -gt 0 ]; do
  case "$1" in
    --from-dir)
      FROM_DIR="${2:?}"
      shift 2
      ;;
    --from-source)
      DO_FROM_SOURCE=1
      shift
      if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
        FROM_SOURCE="$1"
        shift
      else
        FROM_SOURCE="HEAD"
      fi
      ;;
    --version)
      VERSION="${2:?}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

os_name() {
  u=$(uname -s 2>/dev/null || echo unknown)
  case "$u" in
    Linux*) echo linux ;;
    Darwin*) echo darwin ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo "$u" ;;
  esac
}

arch_name() {
  m=$(uname -m 2>/dev/null || echo unknown)
  case "$m" in
    x86_64|amd64) echo x64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo "$m" ;;
  esac
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "need sha256sum or shasum" >&2
    exit 3
  fi
}

OS=$(os_name)
ARCH=$(arch_name)

if [ "$OS" = "windows" ]; then
  echo "Windows is not supported. Install Cockpit inside WSL2 (Ubuntu), then re-run." >&2
  exit 5
fi

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

run_install() {
  local dir="$1"
  if [ ! -f "$dir/install.sh" ]; then
    echo "install.sh missing in $dir" >&2
    exit 1
  fi
  if [ "$(uname -s)" = "Darwin" ] && [ "${COCKPIT_NO_BREW:-0}" != "1" ]; then
    need=""
    command -v bash >/dev/null 2>&1 || need="$need bash"
    command -v tmux >/dev/null 2>&1 || need="$need tmux"
    command -v fswatch >/dev/null 2>&1 || need="$need fswatch"
    if [ -n "$need" ]; then
      if command -v brew >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        brew install $need
      else
        echo "Homebrew is required for:$need" >&2
        echo 'Install Homebrew: https://brew.sh' >&2
        exit 3
      fi
    fi
  fi
  (cd "$dir" && COCKPIT_INSTALL_WEB_BUILD="${COCKPIT_INSTALL_WEB_BUILD:-0}" bash ./install.sh)
  export PATH="$dir/bin:${HOME}/.local/bin:${PATH:-}"
  if [ -x "$dir/bin/cockpit-doctor" ]; then
    "$dir/bin/cockpit-doctor" || true
  elif [ -x "$dir/bin/cockpit" ]; then
    "$dir/bin/cockpit" doctor || true
  fi
  echo "get-cockpit: installed from $dir"
}

if [ -n "$FROM_DIR" ]; then
  FROM_DIR=$(cd "$FROM_DIR" && pwd)
  run_install "$FROM_DIR"
  exit 0
fi

if [ "$DO_FROM_SOURCE" -eq 1 ]; then
  dest="$DATA_HOME/cockpit/src"
  mkdir -p "$DATA_HOME/cockpit"
  if [ -d "$dest/.git" ]; then
    git -C "$dest" fetch --depth 1 origin "$FROM_SOURCE" 2>/dev/null || true
    git -C "$dest" checkout "$FROM_SOURCE" 2>/dev/null || git -C "$dest" checkout FETCH_HEAD || true
  else
    rm -rf "$dest"
    if [ "$FROM_SOURCE" = "HEAD" ]; then
      git clone --depth 1 "$REPO_URL" "$dest"
    else
      git clone --depth 1 --branch "$FROM_SOURCE" "$REPO_URL" "$dest" || git clone --depth 1 "$REPO_URL" "$dest"
    fi
  fi
  echo "get-cockpit: using --from-source (no release tarball)" >&2
  run_install "$dest"
  exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [ "$VERSION" = "latest" ]; then
  if command -v curl >/dev/null 2>&1; then
    tag=$(curl -fsSL "${REPO_URL}/releases/latest" 2>/dev/null | sed -n 's/.*\/tag\/\([^"]*\)".*/\1/p' | head -1 || true)
    [ -n "$tag" ] && VERSION="$tag"
  fi
fi

if [ "$VERSION" = "latest" ] || [ -z "$VERSION" ]; then
  echo "get-cockpit: no release tag resolved; use --from-dir or --from-source" >&2
  exit 1
fi

asset="cockpit-${VERSION}-${OS}-${ARCH}.tar.gz"
url="${RELEASE_BASE}/download/${VERSION}/${asset}"
sums_url="${RELEASE_BASE}/download/${VERSION}/SHA256SUMS"

cd "$tmpdir"
if ! curl -fsSL -o "$asset" "$url"; then
  echo "get-cockpit: download failed: $url" >&2
  echo "hint: use --from-dir DIR or --from-source" >&2
  exit 1
fi
if ! curl -fsSL -o SHA256SUMS "$sums_url"; then
  echo "get-cockpit: SHA256SUMS download failed" >&2
  exit 1
fi

expected=$(awk -v f="$asset" '$2 == f || $2 == "*"f { print $1; exit }' SHA256SUMS)
actual=$(sha256_file "$asset")
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
  echo "get-cockpit: checksum mismatch" >&2
  echo "  expected: ${expected:-missing}" >&2
  echo "  actual:   $actual" >&2
  exit 4
fi

dest="$DATA_HOME/cockpit/$VERSION"
mkdir -p "$dest"
tar -xzf "$asset" -C "$dest" --strip-components=1 2>/dev/null || tar -xzf "$asset" -C "$dest"
run_install "$dest"
