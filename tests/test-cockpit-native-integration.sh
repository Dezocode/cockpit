#!/usr/bin/env bash
# Validate the project-local native plugin, skills, and metadata-only hook
# workflows on a private tmux socket. The live Cockpit server is never used.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
expected_branch="$(git -C "$repo_root" branch --show-current)"
skill_creator_root="/home/dezocode/.codex/skills/.system/skill-creator"
test_root="$(mktemp -d /tmp/cockpit-native-test.XXXXXX)"
tmux_socket="cockpit-native-$RANDOM-$$"
fakebin="$test_root/bin"
config_home="$test_root/config"
test_home="$test_root/home"
session="cockpit-native-test-$$"
tmux_bin="$(command -v tmux)"
mkdir -p "$fakebin" "$config_home" "$test_home"

cleanup() {
  env -u TMUX -u TMUX_PANE "$tmux_bin" -L "$tmux_socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_root"
}
trap cleanup EXIT

# Route every nested Cockpit command to the private socket.
printf '%s\n' '#!/usr/bin/env bash' \
  "exec \"$tmux_bin\" -L \"$tmux_socket\" \"\$@\"" >"$fakebin/tmux"
chmod +x "$fakebin/tmux"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >>"$TEST_CODEX_ARGS"' 'exec sleep 120' >"$fakebin/codex"
printf '%s\n' '#!/usr/bin/env bash' 'exec sleep 120' >"$fakebin/nvim"
chmod +x "$fakebin/codex" "$fakebin/nvim"
export HOME="$test_home"
export PATH="$fakebin:$repo_root/bin:$HOME/.local/bin:/usr/bin:/bin"
export COCKPIT_CONFIG_HOME="$config_home"
export COCKPIT_AUTH_HOME="$config_home"
export TEST_CODEX_ARGS="$test_root/codex.args"
unset TMUX TMUX_PANE

tmux_test() {
  env -u TMUX -u TMUX_PANE "$tmux_bin" -L "$tmux_socket" "$@"
}

now_ns() { date +%s%N; }

map_usefulness() {
  case "$1" in
    cockpit-worktree) printf 'worktree identity and safe binding' ;;
    cockpit-project) printf 'project-root and runtime alignment' ;;
    cockpit-pages) printf 'stable named-page routing' ;;
    cockpit-files) printf 'Files page and 2:FILES reachability' ;;
    cockpit-diff) printf 'scoped Git change visibility' ;;
    cockpit-map) printf 'local topology inspection' ;;
    cockpit-memory) printf 'fail-closed managed memory' ;;
    cockpit-setup) printf 'persistent provider and setup flow' ;;
    cockpit-hooks) printf 'idempotent tmux event dispatch' ;;
    cockpit-plugin) printf 'native Codex plugin lifecycle' ;;
    cockpit-foot-omarchy) printf 'Foot and Omarchy chrome preservation' ;;
    cockpit-regression) printf 'repeatable no-regression validation' ;;
    *) printf 'project-specific Cockpit guidance' ;;
  esac
}

# Worktree operations are tested against a disposable repository so the
# benchmark proves both read-only identity and explicit-add safety.
fixture_repo="$test_root/fixture-repo"
fixture_linked="$test_root/fixture-linked"
mkdir -p "$fixture_repo"
git -C "$fixture_repo" init -q
git -C "$fixture_repo" config user.name 'Cockpit Test'
git -C "$fixture_repo" config user.email 'cockpit-test@example.invalid'
printf '%s\n' 'fixture' >"$fixture_repo/README.md"
git -C "$fixture_repo" add README.md
git -C "$fixture_repo" commit -qm 'fixture'
worktree_info="$(cd -- "$fixture_repo" && "$repo_root/bin/cockpit-worktree" inspect .)"
grep -Fq "git_root=$fixture_repo" <<<"$worktree_info"
grep -Fq 'worktree_count=1' <<<"$worktree_info"
set +e
(cd -- "$fixture_repo" && "$repo_root/bin/cockpit-worktree" add "$fixture_linked" \
  --branch bench/linked >/dev/null 2>&1)
add_without_confirmation=$?
set -e
[[ "$add_without_confirmation" == 2 ]]
(cd -- "$fixture_repo" && "$repo_root/bin/cockpit-worktree" add "$fixture_linked" \
  --branch bench/linked --yes >/dev/null)
grep -Fq 'worktree_count=2' <(cd -- "$fixture_linked" && "$repo_root/bin/cockpit-worktree" inspect .)
printf 'worktree=pass status=identity-and-explicit-add\n'

skill_count=0
while IFS= read -r skill_file; do
  skill_dir="$(dirname -- "$skill_file")"
  skill_name="${skill_dir##*/}"
  start="$(now_ns)"
  python3 "$skill_creator_root/scripts/quick_validate.py" \
    "$skill_dir" >/dev/null
  sed -n '1,180p' "$skill_file" >/dev/null
  end="$(now_ns)"
  elapsed_ms=$(( (end - start) / 1000000 ))
  printf 'skill=%s status=pass elapsed_ms=%s usefulness=%s\n' \
    "$skill_name" "$elapsed_ms" "$(map_usefulness "$skill_name")"
  skill_count=$((skill_count + 1))
done < <(find "$repo_root/plugins/cockpit-native/skills" -mindepth 2 -maxdepth 2 \
  -type f -name SKILL.md -print | sort)
((skill_count >= 10))
[[ "$skill_count" == "$(find -L "$repo_root/.codex/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print | wc -l)" ]]

python3 /home/dezocode/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py \
  "$repo_root/plugins/cockpit-native" >/dev/null

tmux_test -f /dev/null new-session -d -s "$session" -n AGENT -c "$repo_root" 'exec sleep 120'
runtime="$(tmux_test display-message -p -t "$session:AGENT" '#{pane_id}')"
tmux_test set-option -p -t "$runtime" @cockpit_role runtime
tmux_test set-option -p -t "$runtime" @cockpit_runtime_id codex
tmux_test set-option -t "$session" @cockpit_runtime codex
tmux_test set-option -t "$session" @cockpit_modality keyboard
before_windows="$(tmux_test list-windows -t "$session" | wc -l)"
before_panes="$(tmux_test list-panes -s -t "$session" | wc -l)"

"$repo_root/bin/cockpit-hooks-install" >/dev/null
for event in \
  client-attached client-resized client-session-changed session-created \
  after-select-window after-new-window after-rename-window after-resize-pane \
  after-split-window after-kill-pane after-resize-window after-rename-session; do
  grep -Fq "${event}[93]" <(tmux_test show-hooks -g)
done

run_hook() {
  local event=$1 start end elapsed_ms count safe_event output
  safe_event="${event//[^A-Za-z0-9]/_}"
  start="$(now_ns)"
  output="$(COCKPIT_PROJECT_HOOK_OUTPUT=1 cockpit-project-hook "$event" "$session")"
  end="$(now_ns)"
  elapsed_ms=$(( (end - start) / 1000000 ))
  grep -Fq "event=$event" <<<"$output"
  count="$(tmux_test show-options -v -t "$session" "@cockpit_hook_count_${safe_event}")"
  [[ "$count" =~ ^[1-9][0-9]*$ ]]
  [[ "$(tmux_test show-options -v -t "$session" @cockpit_hook_last_event)" == "$event" ]]
  printf 'hook=%s status=pass elapsed_ms=%s effect=metadata-refresh-count-%s\n' \
    "$event" "$elapsed_ms" "$count"
}

for event in \
  client-attached client-resized client-session-changed session-created \
  after-select-window after-new-window after-rename-window after-resize-pane \
  after-split-window after-kill-pane after-resize-window after-rename-session; do
  run_hook "$event"
done

[[ "$(tmux_test show-options -v -t "$session" @cockpit_project_root)" == "$repo_root" ]]
[[ "$(tmux_test show-options -v -t "$session" @cockpit_git_worktree_path)" == "$repo_root" ]]
[[ "$(tmux_test show-options -v -t "$session" @cockpit_git_branch)" == "$expected_branch" ]]
[[ "$(tmux_test show-options -v -t "$session" @cockpit_project_skill_count)" -ge 12 ]]
[[ "$(tmux_test show-options -v -t "$session" @cockpit_project_hook_count)" -ge 12 ]]
[[ "$(tmux_test list-windows -t "$session" | wc -l)" == "$before_windows" ]]
[[ "$(tmux_test list-panes -s -t "$session" | wc -l)" == "$before_panes" ]]

# Exercise the explicit project switch on the same private server. The fake
# provider/editor keep this test entirely offline and make process replacement
# observable without ever starting the user's real Codex or Neovim.
for spec in "FILES:files" "DIFF:diff" "MAP:map" "MEMORY:memory"; do
  name="${spec%%:*}"
  role="${spec##*:}"
  tmux_test new-window -d -t "$session:" -n "$name" -c "$repo_root" 'exec sleep 120'
  page_pane="$(tmux_test display-message -p -t "$session:$name" '#{pane_id}')"
  tmux_test set-option -p -t "$page_pane" @cockpit_role "$role"
done
switch_output="$("$repo_root/bin/cockpit-worktree" use "$fixture_linked" "$session" \
  --yes --restart-agent --restart-files --refresh-derived)"
grep -Fq "switched=$fixture_linked" <<<"$switch_output"
sleep 0.8
grep -Fq -- "-C $fixture_linked" "$TEST_CODEX_ARGS"
for spec in "AGENT:runtime" "FILES:files" "DIFF:diff" "MAP:map" "MEMORY:memory"; do
  name="${spec%%:*}"
  role="${spec##*:}"
  page_pane="$(tmux_test list-panes -s -t "$session" -F '#{pane_id} #{@cockpit_role}' |
    awk -v r="$role" '$2 == r {print $1; exit}')"
  [[ -n "$page_pane" ]]
  [[ "$(tmux_test display-message -p -t "$page_pane" '#{pane_current_path}')" == "$fixture_linked" ]]
  [[ "$(tmux_test display-message -p -t "$page_pane" '#{window_name}')" == "$name" ]]
done
[[ "$(tmux_test show-options -v -t "$session" @cockpit_git_worktree_path)" == "$fixture_linked" ]]
[[ "$(tmux_test show-options -v -t "$session" @cockpit_git_branch)" == bench/linked ]]
printf 'worktree_switch=pass agent-files-derived-pages=aligned\n'

printf 'native_plugin=pass skills=%s hooks=%s files_route=preserved topology=preserved\n' \
  "$skill_count" "$(tmux_test show-options -v -t "$session" @cockpit_project_hook_count)"
