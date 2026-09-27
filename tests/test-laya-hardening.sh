#!/usr/bin/env bash
# C5 hardening contracts (t1127u mint schemas): bearer key never on argv or in
# temp files, task text literal, laya.conf is data, environment wins, HTTP
# errors and malformed answers are "down", Laya's tool pick is allow-listed,
# and a launch without Laya is unchanged.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/fixture.sh
source "$repo_root/tests/lib/fixture.sh"
fixture_init laya-hardening
LAYA_TEST_NAME=laya-hardening
# shellcheck source=lib/laya-fixture.sh
source "$repo_root/tests/lib/laya-fixture.sh"
laya_install_cleanup
unset COCKPIT_LAYA COCKPIT_LAYA_URL COCKPIT_LAYA_TIMEOUT_MS LAYA_HOST LAYA_PORT LAYA_API_KEY XDG_STATE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
export LAYA_TEST_APPLIED="$FIXTURE_TEST_ROOT/applied.log"
route="$repo_root/bin/cockpit-route"
export TMPDIR="$FIXTURE_TEST_ROOT/tmp"
mkdir -p "$TMPDIR"
cd "$FIXTURE_TEST_ROOT"

laya_make_venv
laya_write_providers
laya_write_key
key="$(laya_key)"
port="$(laya_pick_port)"
rec="$FIXTURE_TEST_ROOT/rec"
laya_write_conf 1 "$port" 3000

# --- key-off-argv + key-off-disk: sample ps and the disk during a slowed call ---
laya_start_stub "$port" "$key" "$rec" FAKE_LAYA_SLEEP_MS=1500
bash "$route" --json 'rename x' >"$FIXTURE_TEST_ROOT/slow.out" &
route_pid=$!
saw_curl=0
while kill -0 "$route_pid" 2>/dev/null; do
  procs="$(ps -A -o args= 2>/dev/null || true)"
  if [[ "$procs" == *"$key"* ]]; then
    kill "$route_pid" 2>/dev/null || true
    laya_fail "key-off-argv: bearer key visible in ps"
  fi
  if printf '%s\n' "$procs" | grep -q '^curl .*--config /dev/fd/'; then
    saw_curl=1
    leaks="$(grep -rlF "$key" "$HOME" "$TMPDIR" 2>/dev/null | grep -v '/api.key$' || true)"
    [[ -z "$leaks" ]] || laya_fail "key-off-disk: key copied to $leaks"
  fi
  sleep 0.05
done
wait "$route_pid" || laya_fail "key-off-argv: route failed"
[[ "$saw_curl" == 1 ]] || laya_fail "key-off-argv: sampler never saw the curl call (vacuous)"
[[ "$(cat "$FIXTURE_TEST_ROOT/slow.out")" == *'"laya":"ok"'* && -s "$rec/auth-ok.txt" ]] ||
  laya_fail "key-off-argv: slowed call did not authenticate"
leaks="$(grep -rlF "$key" "$HOME" "$TMPDIR" 2>/dev/null | grep -v '/api.key$' || true)"
[[ -z "$leaks" ]] || laya_fail "key-off-disk: key left in $leaks"
laya_stop_stubs
laya_start_stub "$port" "$key" "$rec"

# --- input-literal: task text reaches Laya verbatim, nothing is interpreted -----
for task in '@/etc/passwd' '@-' "-x http://127.0.0.1:1 \$(touch $FIXTURE_TEST_ROOT/pwned-task)" \
  $'"quoted" \\ back\nnewline `touch '"$FIXTURE_TEST_ROOT"'/pwned-tick`'; do
  bash "$route" --json -- "$task" >/dev/null
  got="$(laya_json_get "$(cat "$rec/body.json")" state.request 2>/dev/null)" ||
    laya_fail "input-literal: Laya received a body that is not JSON for '$task'"
  [[ "$got" == "$task" ]] || laya_fail "input-literal: sent '$got' for '$task'"
done
[[ ! -e "$FIXTURE_TEST_ROOT/pwned-task" && ! -e "$FIXTURE_TEST_ROOT/pwned-tick" ]] || laya_fail "input-literal: task executed"
if grep -q 'root:' "$rec/body.json"; then laya_fail "input-literal: @file was uploaded"; fi

# --- config-is-data: shell/awk in laya.conf never runs; bad values fall back ----
laya_write_conf 1 "$port" 400 \
  "\$(touch $FIXTURE_TEST_ROOT/pwned-subst)" \
  "\`touch $FIXTURE_TEST_ROOT/pwned-backtick\`" \
  "timeout_ms=1; system(\"touch $FIXTURE_TEST_ROOT/pwned-awk\")" \
  "min_confidence=0.6); system(\"touch $FIXTURE_TEST_ROOT/pwned-awk2\"); (1" \
  "max_tier=top; touch $FIXTURE_TEST_ROOT/pwned-semi"
out="$(bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"ok"'* ]] || laya_fail "config-is-data: route $out"
for f in pwned-subst pwned-backtick pwned-awk pwned-awk2 pwned-semi; do
  [[ ! -e "$FIXTURE_TEST_ROOT/$f" ]] || laya_fail "config-is-data: $f executed"
done
laya_write_conf 1 "$port" 400 'url=http://192.0.2.10:8765'
out="$(bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"down"'* && "$out" == *non_loopback_url* ]] || laya_fail "config-is-data: non-loopback url $out"
cp "$HOME/.local/state/cockpit/laya/api.key" "$FIXTURE_TEST_ROOT/key.save"
(umask 077 && printf '$(touch %s/pwned-key)\n' "$FIXTURE_TEST_ROOT" >"$HOME/.local/state/cockpit/laya/api.key")
laya_write_conf 1 "$port" 400
bash "$route" --json 'rename x' >/dev/null
[[ ! -e "$FIXTURE_TEST_ROOT/pwned-key" ]] || laya_fail "config-is-data: api.key was evaluated"
cp "$FIXTURE_TEST_ROOT/key.save" "$HOME/.local/state/cockpit/laya/api.key"

# --- env-wins: environment beats laya.conf ---------------------------------------
closed="$(laya_pick_port)"
laya_write_conf 1 "$closed" 400
out="$(COCKPIT_LAYA_URL="http://127.0.0.1:$port" bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"ok"'* ]] || laya_fail "env-wins: COCKPIT_LAYA_URL $out"
laya_write_conf 0 "$port" 400
out="$(COCKPIT_LAYA=1 bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"ok"'* ]] || laya_fail "env-wins: COCKPIT_LAYA=1 $out"
laya_write_conf 1 "$port" 400
out="$(COCKPIT_LAYA=0 bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"off"'* ]] || laya_fail "env-wins: COCKPIT_LAYA=0 $out"
out="$(COCKPIT_LAYA_DEFAULT_TIER=standard bash "$route" --json 'low-confidence x')"
[[ "$out" == *'"tier":"standard"'* ]] || laya_fail "env-wins: default_tier $out"

# --- http-error: 401/500 are "down", never "ok" --------------------------------
laya_write_key ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000
out="$(bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"down"'* && "$out" == *http_401* && "$out" == *'"tool":"codex"'* ]] || laya_fail "http-error: 401 $out"
cp "$FIXTURE_TEST_ROOT/key.save" "$HOME/.local/state/cockpit/laya/api.key"
laya_stop_stubs
laya_start_stub "$port" "$key" "$rec" FAKE_LAYA_MODE=http500
out="$(bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"down"'* && "$out" == *http_500* ]] || laya_fail "http-error: 500 $out"

# --- malformed: a 200 with a non-JSON body is "down" with a reason -------------
laya_stop_stubs
laya_start_stub "$port" "$key" "$rec" FAKE_LAYA_MODE=malformed
out="$(bash "$route" --json 'rename x')"
[[ "$out" == *'"laya":"down"'* && "$out" == *malformed_json* && "$out" == *'"tier":"cheap"'* ]] || laya_fail "malformed: $out"

# --- tool-allowlist: only runtimes Cockpit offered can be picked ---------------
for forced in 'codex; touch pwned' 'unknownrt' '../../bin/sh'; do
  laya_stop_stubs
  laya_start_stub "$port" "$key" "$rec" FAKE_LAYA_FORCE_TOOL="$forced"
  out="$(bash "$route" --json 'rename x')"
  [[ "$out" == *'"tool":"codex"'* && "$out" == *low_confidence_tool* ]] || laya_fail "tool-allowlist: '$forced' → $out"
done
laya_stop_stubs

# --- launch-unchanged: cockpit-main with Laya absent/off == without a task ------
fake_launch_bin="$FIXTURE_TEST_ROOT/launch-bin"
mkdir -p "$fake_launch_bin"
cat >"$fake_launch_bin/tmux" <<'TMUX'
#!/usr/bin/env bash
printf '%q ' "$@" >>"$TMUX_LOG"
printf '\n' >>"$TMUX_LOG"
case "$1" in
  has-session|show-options) exit 1 ;;
  display-message) printf '%%1\n' ;;
esac
exit 0
TMUX
printf '#!/bin/sh\nexit 0\n' >"$fake_launch_bin/codex"
printf '#!/bin/sh\nexit 0\n' >"$fake_launch_bin/nvim"
# cockpit-idle is backgrounded by cockpit-main; stub it so the log is deterministic.
printf '#!/bin/sh\nexit 0\n' >"$fake_launch_bin/cockpit-idle"
chmod 0755 "$fake_launch_bin/tmux" "$fake_launch_bin/codex" "$fake_launch_bin/nvim" "$fake_launch_bin/cockpit-idle"
launch() {
  local name=$1 mode=$2 dir
  shift 2
  dir="$FIXTURE_TEST_ROOT/launch/$name"
  rm -rf "$dir"
  mkdir -p "$dir/home/.config/cockpit" "$dir/proj"
  git -C "$dir/proj" init -q
  cp "$HOME/.config/cockpit/providers.conf" "$dir/home/.config/cockpit/providers.conf"
  printf 'runtime=notiers\n' >"$dir/home/.config/cockpit/state"
  if [[ "$mode" != absent ]]; then
    (HOME="$dir/home" && laya_make_venv && laya_write_key "$key" &&
      laya_write_conf "$([[ "$mode" == ok ]] && echo 1 || echo 0)" "$port" 2000)
  fi
  env -i PATH="$fake_launch_bin:$repo_root/bin:/usr/bin:/bin" HOME="$dir/home" TERM=xterm \
    TMUX_TMPDIR="$dir" TMUX_LOG="$dir/tmux.log" COCKPIT_SKIP_GATE=1 LAYA_TEST_APPLIED="$LAYA_TEST_APPLIED" "$@" \
    bash "$repo_root/bin/cockpit-main" "$dir/proj" </dev/null >"$dir/stdout" 2>"$dir/stderr" || printf 'rc=%s\n' "$?" >>"$dir/stdout"
  for f in tmux.log stdout stderr; do
    "$LAYA_TEST_PY" - "$dir/$f" "$dir" <<'PY'
import re, sys
p, d = sys.argv[1], sys.argv[2]
s = open(p).read().replace(d, "<RUN>")
s = re.sub(r"cockpit-probe-[0-9]+", "cockpit-probe-<PID>", s)
open(p, "w").write(s)
PY
  done
}
launch plain absent
launch task-absent absent COCKPIT_TASK='fix flaky test'
launch task-off off COCKPIT_TASK='fix flaky test'
for name in task-absent task-off; do
  for f in tmux.log stdout stderr; do
    if ! cmp -s "$FIXTURE_TEST_ROOT/launch/plain/$f" "$FIXTURE_TEST_ROOT/launch/$name/$f"; then
      diff "$FIXTURE_TEST_ROOT/launch/plain/$f" "$FIXTURE_TEST_ROOT/launch/$name/$f" >&2 || true
      laya_fail "launch-unchanged: $name $f differs"
    fi
  done
done
grep -q '@cockpit_runtime_id notiers' "$FIXTURE_TEST_ROOT/launch/plain/tmux.log" ||
  laya_fail "launch-unchanged: fake launch never ran with the saved runtime (vacuous)"
laya_start_stub "$port" "$key" "$rec" FAKE_LAYA_FORCE_TOOL=stubrt
launch task-ok ok COCKPIT_TASK='rename a variable in one file'
grep -q '@cockpit_runtime_id stubrt' "$FIXTURE_TEST_ROOT/launch/task-ok/tmux.log" ||
  laya_fail "launch-unchanged: a real Laya answer did not pick the runtime"

# --- apply-only-ok: absent/off/down never export COCKPIT_PROVIDER/COCKPIT_MODEL or
# run model_apply, even when the default runtime has a tiers= map ----------------
cp "$HOME/.config/cockpit/providers.conf" "$FIXTURE_TEST_ROOT/providers.save"
"$LAYA_TEST_PY" - "$HOME/.config/cockpit/providers.conf" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "start=codex\n"
assert s.count(old) == 1
s = s.replace(old, old + "tiers=cheap:codex-cheap,standard:codex-std,top:codex-top\n"
              "model_apply=printf '%s:%s\\n' \"$COCKPIT_PROVIDER\" \"$COCKPIT_MODEL\" >>\"$LAYA_TEST_APPLIED\"\n")
open(p, "w").write(s)
PY
: >"$LAYA_TEST_APPLIED"
closed="$(laya_pick_port)"
mkdir -p "$FIXTURE_TEST_ROOT/nolaya/.config/cockpit"
cp "$HOME/.config/cockpit/providers.conf" "$FIXTURE_TEST_ROOT/nolaya/.config/cockpit/"
for mode in off down absent; do
  res="$(
    unset COCKPIT_PROVIDER COCKPIT_MODEL
    case "$mode" in
      off) export COCKPIT_LAYA=0 ;;
      down) export COCKPIT_LAYA_URL="http://127.0.0.1:$closed" ;;
      absent) export HOME="$FIXTURE_TEST_ROOT/nolaya" ;;
    esac
    # shellcheck source=../bin/cockpit-lib
    source "$repo_root/bin/cockpit-lib"
    cockpit_route_run 'rename x'
    printf '%s|%s|%s' "$COCKPIT_ROUTE_LAYA" "${COCKPIT_PROVIDER:-}" "${COCKPIT_MODEL:-}"
  )"
  [[ "$res" == "$mode||" ]] || laya_fail "apply-only-ok: $mode exported provider/model ($res)"
done
[[ ! -s "$LAYA_TEST_APPLIED" ]] || laya_fail "apply-only-ok: model_apply ran without Laya: $(cat "$LAYA_TEST_APPLIED")"
laya_stop_stubs
laya_start_stub "$port" "$key" "$rec" FAKE_LAYA_FORCE_TOOL=codex
res="$(
  unset COCKPIT_PROVIDER COCKPIT_MODEL
  # shellcheck source=../bin/cockpit-lib
  source "$repo_root/bin/cockpit-lib"
  cockpit_route_run 'rename x'
  printf '%s|%s|%s' "$COCKPIT_ROUTE_LAYA" "${COCKPIT_PROVIDER:-}" "${COCKPIT_MODEL:-}"
)"
[[ "$res" == 'ok|codex|codex-cheap' && "$(cat "$LAYA_TEST_APPLIED")" == 'codex:codex-cheap' ]] ||
  laya_fail "apply-only-ok: a real Laya answer did not apply the tier ($res, $(cat "$LAYA_TEST_APPLIED"))"
cp "$FIXTURE_TEST_ROOT/providers.save" "$HOME/.config/cockpit/providers.conf"

# --- lib-shell-options: sourcing cockpit-lib and routing keep the caller's options
opts="$(
  set +e +u +o pipefail
  shopt -u nullglob extglob
  before="$-|$(shopt -p nullglob extglob)"
  # shellcheck source=../bin/cockpit-lib
  source "$repo_root/bin/cockpit-lib"
  COCKPIT_LAYA=0 cockpit_route_run 'x'
  cockpit_route_run 'rename x'
  after="$-|$(shopt -p nullglob extglob)"
  [[ "$before" == "$after" ]] && printf same || printf '%s != %s' "$before" "$after"
)"
[[ "$opts" == same ]] || laya_fail "lib-shell-options: $opts"

printf 'laya-hardening: ok (key-off-argv, key-off-disk, input-literal, config-is-data, env-wins, http-error, malformed, tool-allowlist, launch-unchanged, apply-only-ok, lib-shell-options)\n'
