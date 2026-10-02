#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmpdir=$(mktemp -d)
HTTP_PID=""
cleanup() { kill $HTTP_PID 2>/dev/null || true; rm -rf "$tmpdir"; }
trap cleanup EXIT

fakebin="$tmpdir/fakebin"
mkdir -p "$fakebin"
cat > "$fakebin/uname" <<'U'
#!/bin/sh
[ "$1" = "-s" ] && { echo MINGW64_NT; exit 0; }
[ "$1" = "-m" ] && { echo x86_64; exit 0; }
/usr/bin/uname "$@"
U
chmod +x "$fakebin/uname"
set +e
PATH="$fakebin:/usr/bin:/bin" bash "$root/scripts/get-cockpit.sh" >"$tmpdir/out" 2>"$tmpdir/err"
rc=$?
set -e
[ "$rc" = "5" ] || { echo "get-cockpit: FAIL unsupported-os rc=$rc"; cat "$tmpdir/err"; exit 1; }

mkdir -p "$tmpdir/src/bin" "$tmpdir/src/scripts"
cp "$root/scripts/get-cockpit.sh" "$tmpdir/src/scripts/get-cockpit.sh"
install -m 0755 /dev/stdin "$tmpdir/src/install.sh" <<'SH'
#!/bin/sh
echo stub-install ok
SH
install -m 0755 /dev/stdin "$tmpdir/src/bin/cockpit-doctor" <<'SH'
#!/bin/sh
echo "{\"os\":\"linux\",\"arch\":\"x64\",\"required_failed\":0,\"checks\":[]}"
SH
HOME="$tmpdir/home1" XDG_DATA_HOME="$tmpdir/data1" \
  bash "$tmpdir/src/scripts/get-cockpit.sh" --from-dir "$tmpdir/src" >"$tmpdir/from.out" 2>"$tmpdir/from.err"
rg -q 'get-cockpit: installed' "$tmpdir/from.out" || { echo "from-dir FAIL"; cat "$tmpdir/from.out" "$tmpdir/from.err"; exit 1; }

mkdir -p "$tmpdir/pkg/bin" "$tmpdir/www/download/vtest"
install -m 0755 /dev/stdin "$tmpdir/pkg/install.sh" <<'SH'
#!/bin/sh
echo installed
SH
cp "$tmpdir/src/bin/cockpit-doctor" "$tmpdir/pkg/bin/cockpit-doctor"
tar -czf "$tmpdir/www/download/vtest/cockpit-vtest-linux-x64.tar.gz" -C "$tmpdir" pkg
( cd "$tmpdir/www/download/vtest" && if command -v sha256sum >/dev/null; then sha256sum cockpit-vtest-linux-x64.tar.gz > SHA256SUMS; else shasum -a 256 cockpit-vtest-linux-x64.tar.gz > SHA256SUMS; fi )
cp "$tmpdir/www/download/vtest/cockpit-vtest-linux-x64.tar.gz" "$tmpdir/good.tgz"
echo x >> "$tmpdir/www/download/vtest/cockpit-vtest-linux-x64.tar.gz"

python3 "$root/tests/lib/http-fixture-server.py" "$tmpdir/www" "$tmpdir/port" &
HTTP_PID=$!
for i in $(seq 1 50); do [ -f "$tmpdir/port" ] && break; sleep 0.05; done
port=$(cat "$tmpdir/port")
set +e
HOME="$tmpdir/home-bad" XDG_DATA_HOME="$tmpdir/data-bad" \
  COCKPIT_RELEASE_BASE="http://127.0.0.1:${port}" \
  bash "$root/scripts/get-cockpit.sh" --version vtest >"$tmpdir/bad.out" 2>"$tmpdir/bad.err"
brc=$?
set -e
kill "$HTTP_PID" 2>/dev/null || true
wait "$HTTP_PID" 2>/dev/null || true
HTTP_PID=""
[ "$brc" = "4" ] || { echo "get-cockpit: FAIL sha-mismatch rc=$brc"; cat "$tmpdir/bad.err"; exit 1; }

mv "$tmpdir/good.tgz" "$tmpdir/www/download/vtest/cockpit-vtest-linux-x64.tar.gz"
( cd "$tmpdir/www/download/vtest" && if command -v sha256sum >/dev/null; then sha256sum cockpit-vtest-linux-x64.tar.gz > SHA256SUMS; else shasum -a 256 cockpit-vtest-linux-x64.tar.gz > SHA256SUMS; fi )
rm -f "$tmpdir/port"
python3 "$root/tests/lib/http-fixture-server.py" "$tmpdir/www" "$tmpdir/port" &
HTTP_PID=$!
for i in $(seq 1 50); do [ -f "$tmpdir/port" ] && break; sleep 0.05; done
port=$(cat "$tmpdir/port")
set +e
HOME="$tmpdir/home-good" XDG_DATA_HOME="$tmpdir/data-good" \
  COCKPIT_RELEASE_BASE="http://127.0.0.1:${port}" \
  bash "$root/scripts/get-cockpit.sh" --version vtest >"$tmpdir/good.out" 2>"$tmpdir/good.err"
grc=$?
set -e
kill "$HTTP_PID" 2>/dev/null || true
wait "$HTTP_PID" 2>/dev/null || true
HTTP_PID=""
[ "$grc" = "0" ] || { echo "get-cockpit: FAIL release-sha rc=$grc"; cat "$tmpdir/good.out" "$tmpdir/good.err"; exit 1; }

echo "get-cockpit: ok (release-sha-ok, sha-mismatch-refused, from-dir, unsupported-os-refused)"
