#!/usr/bin/env bash
# Cockpit 2 release bundle — web + server + TUI + deploy (no secrets)
set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
version="${COCKPIT_VERSION:-2.2.0}"
out="$root/dist/release"
name="cockpit-${version}"
staging="$out/$name"

rm -rf "$staging"
mkdir -p "$staging"/{app,bin,bench/cockpit,fixtures,marketing,stage,scripts,deploy,tmp/t847u}

printf 'Building cockpit %s release bundle\n' "$version"

# TUI (preserved)
cp -a "$root/bin/cockpit"* "$staging/bin/" 2>/dev/null || true
cp -a "$root/bin/codex-cockpit"* "$staging/bin/" 2>/dev/null || true
cp -a "$root/bin/cpr" "$staging/bin/" 2>/dev/null || true
cp -a "$root/install.sh" "$staging/"
cp -a "$root/LICENSE" "$staging/"
cp -a "$root/README.md" "$staging/"
cp -a "$root/plugins" "$staging/"
cp -a "$root/stage" "$staging/stage"
cp -a "$root/fixtures" "$staging/fixtures"
cp -a "$root/packaging" "$staging/packaging" 2>/dev/null || true
cp -a "$root/tmp/t847u" "$staging/tmp/t847u" 2>/dev/null || true
cp -a "$root/deploy/cockpit-web.service" "$root/deploy/nginx-cockpit.conf" \
  "$root/deploy/hostinger-grok-build-install.sh" "$staging/deploy/" 2>/dev/null || true
cp -a "$root/scripts/install-hostinger.sh" "$root/scripts/hostinger-grok-build.sh" \
  "$root/scripts/hostinger-health.sh" "$staging/scripts/" 2>/dev/null || true
cp -a "$root/bench/cockpit" "$staging/bench/cockpit"
cp -a "$root/marketing" "$staging/marketing"

# Web GUI
if [[ -d "$root/app" ]]; then
  (cd "$root/app" && pnpm install --frozen-lockfile 2>/dev/null || pnpm install)
  (cd "$root/app" && pnpm build)
  (cd "$root/app" && pnpm exec tsc -p tsconfig.server.json)
  cp -a "$root/app/dist" "$staging/app/dist"
  cp -a "$root/app/dist-server" "$staging/app/dist-server"
  cp -a "$root/app/package.json" "$root/app/pnpm-lock.yaml" "$staging/app/"
  cp -a "$root/app/server" "$staging/app/server"
fi

cat >"$staging/RELEASE.txt" <<EOF
cockpit ${version}
Product: cockpit (never codex-cockpit)
Seed: cockpit-20260907
Install TUI: ./install.sh
Install web: COCKPIT_INSTALL_WEB_BUILD=1 ./install.sh
Hostinger: ./scripts/install-hostinger.sh
Hostinger grok-build: ./deploy/hostinger-grok-build-install.sh
Hostinger grok-build (curl path): ./scripts/hostinger-grok-build.sh
Health: ./scripts/hostinger-health.sh
Install root: /opt/cockpit (NOT /root/.grok or saul-go)
EOF

mkdir -p "$out"
tar -czf "$out/${name}-linux-x64.tar.gz" -C "$out" "$name"

# Web-only slim bundle for static+API deploy
mkdir -p "$out/${name}-web"/{packaging/systemd,packaging/nginx,scripts,deploy}
cp -a "$staging/app/dist" "$out/${name}-web/"
cp -a "$staging/app/dist-server" "$out/${name}-web/" 2>/dev/null || true
cp -a "$staging/app/server" "$out/${name}-web/"
cp -a "$staging/app/package.json" "$out/${name}-web/"
cp -a "$root/packaging/systemd/cockpit-web.service" "$root/packaging/systemd/cockpit-web-heal.sh" \
  "$out/${name}-web/packaging/systemd/"
cp -a "$root/packaging/nginx/cockpit.conf" "$out/${name}-web/packaging/nginx/"
cp -a "$root/scripts/install-hostinger.sh" "$root/scripts/hostinger-grok-build.sh" \
  "$root/scripts/hostinger-health.sh" "$out/${name}-web/scripts/"
cp -a "$root/deploy/cockpit-web.service" "$root/deploy/nginx-cockpit.conf" \
  "$root/deploy/hostinger-grok-build-install.sh" "$out/${name}-web/deploy/"
tar -czf "$out/${name}-web.tar.gz" -C "$out" "${name}-web"

printf 'Release artifacts:\n'
ls -lh "$out"/*.tar.gz
printf '%s\n' "$out"
