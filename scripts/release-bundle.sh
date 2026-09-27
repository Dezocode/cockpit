#!/usr/bin/env bash
# Cockpit 2 release bundle — web + server + TUI + deploy (no secrets)
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
# Version comes from app/package.json (read as JSON data), unless the caller
# pins COCKPIT_VERSION; scripts/check-versions.sh guards the manifests.
version="${COCKPIT_VERSION:-$(node -p 'require(process.argv[1]).version' "$root/app/package.json")}"
[[ -n "$version" && "$version" != undefined ]] || {
  printf 'release-bundle: no version in app/package.json\n' >&2
  exit 1
}

# Target names the artifact (<os>-<arch>); bundles are built natively per runner.
if [[ -z "${COCKPIT_TARGET:-}" ]]; then
  case "$(uname -s)" in
    Linux) target_os=linux ;;
    Darwin) target_os=darwin ;;
    *) printf 'release-bundle: unsupported OS %s\n' "$(uname -s)" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) target_arch=x64 ;;
    arm64 | aarch64) target_arch=arm64 ;;
    *) printf 'release-bundle: unsupported arch %s\n' "$(uname -m)" >&2; exit 1 ;;
  esac
  COCKPIT_TARGET="${target_os}-${target_arch}"
fi
target="$COCKPIT_TARGET"
[[ "$target" =~ ^(linux|darwin)-(x64|arm64)$ ]] || {
  printf 'release-bundle: bad COCKPIT_TARGET %s\n' "$target" >&2
  exit 1
}
# The web tarball is platform-neutral and published once, from the Linux leg.
web_tarball="${COCKPIT_WEB_TARBALL:-$([[ "$target" == linux-* ]] && echo 1 || echo 0)}"
out="$root/dist/release"
name="cockpit-${version}"
staging="$out/$name"

rm -rf "$staging"
mkdir -p "$staging"/{app,bin,bench/cockpit,fixtures,marketing,stage,scripts,deploy,tmp/t847u}

printf 'Building cockpit %s release bundle (%s)\n' "$version" "$target"

# TUI (preserved)
cp -a "$root/bin/cockpit"* "$staging/bin/" 2>/dev/null || true
cp -a "$root/bin/cockpit-legacy-alias" "$root/bin/cockpit-legacy-names.list" "$staging/bin/" 2>/dev/null || true
cp -a "$root/bin/cpr" "$staging/bin/" 2>/dev/null || true
cp -a "$root/install.sh" "$staging/"
cp -a "$root/LICENSE" "$staging/"
cp -a "$root/README.md" "$staging/"
cp -a "$root/plugins" "$staging/"
cp -a "$root/stage" "$staging/stage"
cp -a "$root/fixtures" "$staging/fixtures"
cp -a "$root/packaging" "$staging/packaging" 2>/dev/null || true
cp -a "$root/tmp/t847u" "$staging/tmp/t847u" 2>/dev/null || true
cp -a "$root/scripts/install-hostinger.sh" \
  "$root/scripts/hostinger-health.sh" "$staging/scripts/" 2>/dev/null || true
cp -a "$root/bench/cockpit" "$staging/bench/cockpit"
cp -a "$root/marketing" "$staging/marketing"

# Web GUI
if [[ -d "$root/app" ]]; then
  (cd "$root/app" && pnpm install --frozen-lockfile)
  (cd "$root/app" && pnpm build)
  # build:server = tsc + fleet/tz-centroids.json, which dist-server reads at load.
  (cd "$root/app" && pnpm run build:server)
  cp -a "$root/app/dist" "$staging/app/dist"
  cp -a "$root/app/dist-server" "$staging/app/dist-server"
  cp -a "$root/app/package.json" "$root/app/pnpm-lock.yaml" "$staging/app/"
  cp -a "$root/app/server" "$staging/app/server"
fi

cat >"$staging/RELEASE.txt" <<EOF
cockpit ${version}
Target: ${target}
Product: cockpit
Seed: cockpit-20260907
Install TUI: ./install.sh
Install web: COCKPIT_INSTALL_WEB_BUILD=1 ./install.sh
Hostinger: ./scripts/install-hostinger.sh
Health: ./scripts/hostinger-health.sh --wait
Install root: /opt/cockpit (NOT /root/.grok or saul-go)
EOF

mkdir -p "$out"
tar -czf "$out/${name}-${target}.tar.gz" -C "$out" "$name"

# Web-only slim bundle for static+API deploy
if [[ "$web_tarball" == 1 ]]; then
  mkdir -p "$out/${name}-web"/{packaging/systemd,packaging/nginx,scripts,deploy}
  cp -a "$staging/app/dist" "$out/${name}-web/"
  cp -a "$staging/app/dist-server" "$out/${name}-web/" 2>/dev/null || true
  cp -a "$staging/app/server" "$out/${name}-web/"
  cp -a "$staging/app/package.json" "$out/${name}-web/"
  cp -a "$root/packaging/systemd/cockpit-web.service" "$root/packaging/systemd/cockpit-web-heal.sh" \
    "$out/${name}-web/packaging/systemd/"
  cp -a "$root/packaging/nginx/cockpit.conf" "$out/${name}-web/packaging/nginx/"
  cp -a "$root/scripts/install-hostinger.sh" \
    "$root/scripts/hostinger-health.sh" "$out/${name}-web/scripts/"
  tar -czf "$out/${name}-web.tar.gz" -C "$out" "${name}-web"
fi

printf 'Release artifacts:\n'
ls -lh "$out"/*.tar.gz
printf '%s\n' "$out"
