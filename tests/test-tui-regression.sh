#!/usr/bin/env bash
# Fail-closed TUI regression pack for v0.1/cc4f1ee layout contract (PR #1 PREP).
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../bin/cockpit-lib
source "$repo_root/bin/cockpit-lib"

test_root="$(mktemp -d /tmp/cockpit-tui-regression.XXXXXX)"
test_home="$test_root/home"
tmux_root="$test_root/tmux"
session=cockpit
uid="$(id -u)"
canonical_socket="/tmp/tmux-${uid}/default"
paste_stub="$repo_root/tests/fixtures/codex-paste-stub.sh"
stub_marker="$test_root/submit.marker"
stub_state="$test_root/submit.state"
bar_pid=""

cleanup() {
  if [[ "$bar_pid" =~ ^[0-9]+$ ]]; then
    kill "$bar_pid" >/dev/null 2>&1 || true
  fi
  env -u TMUX -u TMUX_PANE tmux kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

fail() {
  printf 'TUI regression FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'TUI regression OK: %s\n' "$*"
}

tmux_test() {
  env -u TMUX -u TMUX_PANE tmux "$@"
}

export HOME="$test_home"
export TMUX_TMPDIR="$tmux_root"
export PATH="$test_home/.local/bin:$repo_root/bin:/usr/bin:/bin"
unset TMUX TMUX_PANE

mkdir -p "$test_home/.config/cockpit"
install -m 0644 "$repo_root/tests/fixtures/providers.conf" "$test_home/.config/cockpit/providers.conf"
chmod +x "$paste_stub"

assert_source_contract() {
  local main="$repo_root/bin/cockpit-main"
  grep -q 'new-session.*-n AGENT' "$main" || fail 'cockpit-main missing AGENT window bootstrap'
  for name in FILES DIFF MAP MEMORY SETUP PRS; do
    grep -q "new-window.*-n ${name}" "$main" || fail "cockpit-main missing ${name} window bootstrap"
  done
  grep -q 'cockpit-memory-watch' "$main" || fail 'cockpit-main missing MEMORY watcher bootstrap'
  grep -q 'tag "$session:MEMORY" MEMORY memory' "$main" || fail 'cockpit-main missing MEMORY role tag'
  grep -q 'memory|MEMORY' "$repo_root/bin/cockpit-touch" ||
    fail 'cockpit-touch missing MEMORY routing'
  grep -q 'MEMORY|memory' "$repo_root/bin/cockpit-wake" ||
    fail 'cockpit-wake missing MEMORY wake routing'
  grep -q 'reload_view memory' "$repo_root/bin/cockpit-reload-views" ||
    fail 'cockpit-reload-views missing MEMORY derived view'
  pass 'source contract: seven-window bootstrap with MEMORY named page'
}

assert_memory_bind_contract() {
  local conf="$repo_root/stage/tmux/cockpit.conf"
  if grep -Eiq 'F10.*memory|memory.*F10|bind.*F10.*memory' "$conf"; then
    fail 'F10 memory bind landed inside MAP/TUI overlay'
  fi
  if grep -E 'cockpit-touch.*memory|memory.*cockpit-touch' "$conf"; then
    fail 'prefix/M memory bind landed in tmux overlay (must not route inside MAP)'
  fi
  if grep -E 'bind.*[[:space:]]+[yY][[:space:]].*memory' "$conf"; then
    fail 'prefix+y memory bind landed in tmux overlay'
  fi
  pass 'bind contract: no F10/prefix memory routing in tmux overlay'
}

bootstrap_canonical_session() {
  local root=$1
  tmux_test kill-server >/dev/null 2>&1 || true
  tmux_test -f /dev/null new-session -d -s "$session" -n AGENT -c "$root" \
    "export COCKPIT_PASTE_STUB_MARKER=$(printf '%q' "$stub_marker"); \
export COCKPIT_PASTE_STUB_STATE=$(printf '%q' "$stub_state"); \
exec bash --norc $(printf '%q' "$paste_stub")"
  tmux_test set-option -p -t "$session:AGENT" @cockpit_role runtime
  tmux_test set-option -t "$session" @cockpit_runtime test
  tmux_test set-option -t "$session" @cockpit 1

  for spec in "FILES:files" "DIFF:diff" "MAP:map" "MEMORY:memory" "SETUP:setup" "PRS:prs"; do
    local name=${spec%%:*} role=${spec##*:}
    tmux_test new-window -d -t "$session:" -n "$name" -c "$root" 'exec sleep 600'
    local pane
    pane="$(tmux_test display-message -p -t "$session:$name" '#{pane_id}')"
    tmux_test set-option -p -t "$pane" @cockpit_role "$role"
  done
}

assert_window_topology() {
  local -a names=()
  local count name agent_win map_win pane role window nested=0 agent_panes memory_in_map=0
  local expect_count=${1:-7}

  mapfile -t names < <(tmux_test list-windows -t "$session" -F '#{window_name}' | sort)
  count="${#names[@]}"
  [[ "$count" -eq "$expect_count" ]] ||
    fail "expected ${expect_count} windows, got ${count}: ${names[*]}"

  for expected in AGENT DIFF FILES MAP MEMORY PRS SETUP; do
    printf '%s\n' "${names[@]}" | grep -Fxq "$expected" || fail "missing window ${expected}"
  done

  agent_win="$(tmux_test display-message -p -t "$session:AGENT" '#{window_id}')"
  map_win="$(tmux_test display-message -p -t "$session:MAP" '#{window_id}')"
  while read -r pane role window; do
    [[ -n "$pane" ]] || continue
    case "$role" in
      files|diff|map|setup|prs)
        [[ "$window" != "$agent_win" ]] || nested=1
        ;;
      memory)
        [[ "$window" != "$agent_win" ]] || nested=1
        [[ "$window" != "$map_win" ]] || memory_in_map=1
        ;;
    esac
  done < <(tmux_test list-panes -s -t "$session" -F '#{pane_id} #{@cockpit_role} #{window_id}')

  [[ "$nested" -eq 0 ]] || fail 'canonical pages are nested into AGENT (cc4f1ee violation)'
  [[ "$memory_in_map" -eq 0 ]] || fail 'MEMORY is nested inside MAP (must be additive named page)'

  agent_panes="$(tmux_test list-panes -t "$session:AGENT" | wc -l | tr -d ' ')"
  [[ "$agent_panes" -le 2 ]] || fail "AGENT window has ${agent_panes} panes (not 5-up stack)"

  if ((expect_count == 7)); then
    printf '%s\n' "${names[@]}" | grep -Fxq MEMORY ||
      fail 'canonical session must include MEMORY named window'
  elif printf '%s\n' "${names[@]}" | grep -Fxq MEMORY; then
    fail 'baseline session must stay windows==6 without MEMORY chrome'
  fi

  pass "topology: windows==${expect_count}, pages not nested, AGENT not 5-up, MEMORY not in MAP"
}

assert_no_extra_client() {
  local clients
  clients="$(tmux_test list-clients -t "$session" 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$clients" == 0 ]] || fail "extra tmux client attached (${clients}); Foot must be sole size owner"
  pass 'clients: zero attached (no second client / attach probe)'
}

wait_paste_indicator() {
  local pane=$1 tries=0 cap
  while ((tries < 80)); do
    cap="$(tmux_test capture-pane -t "$pane" -p -S -200 2>/dev/null || true)"
    if grep -Eq '\[Pasted Content [0-9]+ chars\]' <<<"$cap"; then
      printf '%s\n' "$cap"
      return 0
    fi
    sleep 0.05
    tries=$((tries + 1))
  done
  return 1
}

assert_runtime_is_codex_pane() {
  local runtime=$1 bar=$2
  [[ "$runtime" != "$bar" ]] ||
    fail 'runtime Codex pane aliases BAR pane (must inject to Codex only)'
  [[ "$(tmux_test display-message -p -t "$runtime" '#{@cockpit_role}')" == runtime ]] ||
    fail 'Codex pane is not tagged runtime'
  [[ "$(tmux_test display-message -p -t "$bar" '#{@cockpit_role}')" == bar ]] ||
    fail 'BAR pane is not tagged bar'
}

assert_inject_submit() {
  local root=$1 runtime bar runtime_cap bar_cap payload

  rm -f "$stub_marker" "$stub_state"
  : >"$stub_state"

  runtime="$(
    tmux_test list-panes -s -t "$session" -F '#{pane_id} #{@cockpit_role}' |
      awk '$2 == "runtime" { print $1; exit }'
  )"
  bar="$(
    tmux_test list-panes -s -t "$session" -F '#{pane_id} #{@cockpit_role}' |
      awk '$2 == "bar" { print $1; exit }'
  )"
  [[ -n "$runtime" && -n "$bar" ]] || fail 'runtime/bar panes missing for inject test'
  assert_runtime_is_codex_pane "$runtime" "$bar"

  payload='inject-payload-for-tui-regression'
  tmux_test set-buffer "$payload"

  # Immediate C-m after paste must not submit (Codex pane protocol).
  tmux_test paste-buffer -t "$runtime" -d \; send-keys -t "$runtime" C-m
  sleep 0.15
  if [[ -f "$stub_marker" ]]; then
    grep -q '^SUBMITTED:' "$stub_marker" &&
      fail 'immediate C-m after paste submitted (must wait for [Pasted Content] chip)'
  else
    runtime_cap="$(tmux_test capture-pane -t "$runtime" -p -S -200)"
    grep -q "SUBMITTED:${payload}" <<<"$runtime_cap" &&
      fail 'immediate C-m after paste submitted (must wait for [Pasted Content] chip)'
  fi
  bar_cap="$(tmux_test capture-pane -t "$bar" -p -S -50)"
  grep -q SUBMITTED <<<"$bar_cap" && fail 'paste/submit leaked into BAR pane'
  grep -q PREMATURE_ENTER <<<"$bar_cap" && fail 'paste/submit touched BAR pane'

  # Respawn stub for positive path.
  rm -f "$stub_marker"
  : >"$stub_state"
  tmux_test respawn-pane -k -t "$runtime" \
    "export COCKPIT_PASTE_STUB_MARKER=$(printf '%q' "$stub_marker"); \
export COCKPIT_PASTE_STUB_STATE=$(printf '%q' "$stub_state"); \
exec bash --norc $(printf '%q' "$paste_stub")"
  sleep 0.2
  runtime="$(
    tmux_test list-panes -s -t "$session" -F '#{pane_id} #{@cockpit_role}' |
      awk '$2 == "runtime" { print $1; exit }'
  )"
  tmux_test set-buffer "$payload"
  tmux_test paste-buffer -t "$runtime" -d
  runtime_cap="$(wait_paste_indicator "$runtime")" ||
    fail 'paste chip [Pasted Content N chars] never appeared'
  grep -Eq '\[Pasted Content [0-9]+ chars\]' <<<"$runtime_cap" ||
    fail 'paste chip missing from runtime capture'
  grep -q '^INDICATOR:' "$stub_state" ||
    fail 'paste chip missing from stub state log'

  tmux_test send-keys -t "$runtime" Enter
  sleep 0.35
  grep -Fx "SUBMITTED:${payload}" "$stub_marker" 2>/dev/null ||
    fail 'Enter after paste chip did not submit to runtime pane %0'

  bar_cap="$(tmux_test capture-pane -t "$bar" -p -S -50)"
  grep -q SUBMITTED <<<"$bar_cap" && fail 'submit output appeared in BAR pane'

  assert_window_topology 7
  pass 'inject+submit: paste-buffer %0, wait chip, Enter; BAR untouched; windows stay 7'
}

assert_memory_not_nested() {
  local map_win memory_pane memory_win
  map_win="$(tmux_test display-message -p -t "$session:MAP" '#{window_id}')"
  memory_pane="$(tmux_test display-message -p -t "$session:MEMORY" '#{pane_id}')"
  tmux_test set-option -p -t "$memory_pane" @cockpit_role memory
  memory_win="$(tmux_test display-message -p -t "$memory_pane" '#{window_id}')"
  [[ "$memory_win" != "$map_win" ]] ||
    fail 'MEMORY must not be a second pane inside MAP'
  while read -r role window; do
    [[ "$window" == "$map_win" && "$role" == memory ]] &&
      fail 'memory role appeared inside MAP window'
  done < <(tmux_test list-panes -s -t "$session" -F '#{@cockpit_role} #{window_id}')
  pass 'MEMORY topology: named page, not nested in MAP or AGENT'
}

assert_platform_layout_classes() {
  "$repo_root/tests/test-platform-profile.sh" >/dev/null
  pass 'layout class adapters: foot/generic-desktop/macos-terminal/termius-ios'
}

assert_termius_toolbar_touch() {
  "$repo_root/tests/test-termius-touch.sh" >/dev/null
  pass 'Termius touch + Agent toolbar responsiveness (existing regression)'
}

assert_socket_path_documented() {
  [[ "$canonical_socket" == "/tmp/tmux-${uid}/default" ]] ||
    fail "unexpected canonical socket path: ${canonical_socket}"
  pass "canonical socket path ${canonical_socket} (session name ${session})"
}

main() {
  local project="$test_root/project"
  mkdir -p "$project"

  assert_source_contract
  assert_memory_bind_contract
  assert_socket_path_documented
  bootstrap_canonical_session "$project"
  assert_window_topology 7
  assert_no_extra_client

  tmux_test set-option -t "$session" @cockpit_profile termius-ios
  tmux_test set-option -t "$session" @cockpit_modality touch
  cockpit-ensure-bar "$session" >/dev/null
  sleep 0.5
  assert_no_extra_client
  assert_inject_submit "$project"
  assert_memory_not_nested
  assert_platform_layout_classes
  assert_termius_toolbar_touch

  printf '%s\n' 'TUI regression pack: PASS'
}

main "$@"
