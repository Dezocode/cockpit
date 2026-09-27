#!/usr/bin/env bash
# C4 workflow lint (t1127u): the must_absent probes (each must print nothing),
# yq structure checks, positive twins, then actionlint over .github/workflows.
# Fail closed: a missing rg / yq v4 / actionlint, an rg error (exit >= 2) or a
# yq error is a finding, never a silent pass. This script excludes itself.
#
#   test-workflow-lint.sh               lint this checkout, then self-test the
#                                       detectors on planted mutations
#   test-workflow-lint.sh --root DIR    lint a copy (no git checks, no self-test)
#
# yq and actionlint are pinned and checksum-verified; they are fetched into
# ${XDG_CACHE_HOME:-$HOME/.cache}/cockpit-lint unless COCKPIT_YQ /
# COCKPIT_ACTIONLINT name a binary. COCKPIT_LINT_OFFLINE=1 forbids fetching.
# COCKPIT_LINT_REQUIRE_BASE=1 makes a missing C4 start commit a finding
# (CI `versions` job checks out full history); otherwise a shallow clone falls
# back to scripts/check-exec-bits.sh for the mode-drop check.
set -euo pipefail

start_sha=c01379ab6b1422c85cf3a94c82c548c38e8565a9
self="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$self")/.." && pwd)"
root="$repo_root"
copy_mode=0
if [[ "${1:-}" == --root ]]; then
  [[ $# -eq 2 && -d "$2" ]] || { echo "usage: ${0##*/} [--root DIR]" >&2; exit 2; }
  root="$(cd -- "$2" && pwd)"
  copy_mode=1
elif [[ $# -gt 0 ]]; then
  echo "usage: ${0##*/} [--root DIR]" >&2
  exit 2
fi
cd "$root"

# shellcheck source=bin/cockpit-portable-lib
source "$repo_root/bin/cockpit-portable-lib"

actionlint_version=1.7.12
yq_version=4.53.6
pinned_sha() {
  case "$1" in
    actionlint_linux_amd64) echo 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 ;;
    actionlint_linux_arm64) echo 325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6 ;;
    actionlint_darwin_amd64) echo 5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644 ;;
    actionlint_darwin_arm64) echo aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f ;;
    yq_linux_amd64) echo 38b907b21b1b04327fb9481c595331d925a67c6ee1aabd0ef419d0b7d12dfb3d ;;
    yq_linux_arm64) echo d5e7531273d45c5d4b7abb4a1597c47a0fecb5d6b081dfa755064b38ffcc34f4 ;;
    yq_darwin_amd64) echo cf8304676c6572960a3720a189fd42e7038bf989dc181f0c05019a2883caf540 ;;
    yq_darwin_arm64) echo 4e2b18f4242c720965af7919dc0573819474cecf03a71b6cd7656025f2e5162c ;;
    *) return 1 ;;
  esac
}

# Also reached inside $(resolve_tool ...), so the message goes to stderr.
tool_fail() {
  printf 'workflow-lint: FAIL (%s)\n' "$1" >&2
  exit 1
}

platform() {
  local os arch
  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *) return 1 ;;
  esac
  printf '%s_%s\n' "$os" "$arch"
}

# resolve_tool NAME -> absolute path of the pinned binary (fetched if needed).
resolve_tool() {
  local name=$1 plat version url member cache dir tarball want got
  plat="$(platform)" || tool_fail "$name not found (no pinned build for $(uname -s) $(uname -m))"
  if [[ "$name" == yq ]]; then
    version=$yq_version
    url="https://github.com/mikefarah/yq/releases/download/v${version}/yq_${plat}.tar.gz"
    member="./yq_${plat}"
  else
    version=$actionlint_version
    url="https://github.com/rhysd/actionlint/releases/download/v${version}/actionlint_${version}_${plat}.tar.gz"
    member=actionlint
  fi
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/cockpit-lint"
  dir="$cache/${name}-${version}-${plat}"
  if [[ -x "$dir/$name" ]]; then
    printf '%s\n' "$dir/$name"
    return 0
  fi
  [[ "${COCKPIT_LINT_OFFLINE:-0}" != 1 ]] || tool_fail "$name not found (offline, no pinned $name ${version} in $cache)"
  command -v curl >/dev/null 2>&1 || tool_fail "$name not found (curl missing, cannot fetch)"
  want="$(pinned_sha "${name}_${plat}")" || tool_fail "$name not found (no checksum for $plat)"
  mkdir -p "$cache"
  tarball="$(mktemp "$cache/.${name}.XXXXXX")"
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tarball" "$url"; then
    rm -f "$tarball"
    tool_fail "$name not found (download failed: $url)"
  fi
  got="$(cockpit_sha256 "$tarball")"
  if [[ "$got" != "$want" ]]; then
    rm -f "$tarball"
    tool_fail "$name checksum mismatch for $url (got ${got:-none})"
  fi
  rm -rf "$dir.tmp"
  mkdir -p "$dir.tmp"
  tar -xzf "$tarball" -C "$dir.tmp" "$member" || { rm -f "$tarball"; tool_fail "$name not found (bad archive)"; }
  rm -f "$tarball"
  [[ "$member" == "$name" ]] || mv "$dir.tmp/$member" "$dir.tmp/$name"
  rm -rf "$dir"
  mv "$dir.tmp" "$dir"
  [[ -x "$dir/$name" ]] || tool_fail "$name not found (archive member not executable)"
  printf '%s\n' "$dir/$name"
}

command -v rg >/dev/null 2>&1 || tool_fail "rg not found"
if [[ -n "${COCKPIT_YQ:-}" ]]; then
  yq_bin=$COCKPIT_YQ
else
  yq_bin="$(resolve_tool yq)"
fi
"$yq_bin" --version 2>/dev/null | grep -Eq 'mikefarah.* v?4\.' || tool_fail "yq v4 (mikefarah) not found at $yq_bin"
if [[ -n "${COCKPIT_ACTIONLINT:-}" ]]; then
  actionlint_bin=$COCKPIT_ACTIONLINT
else
  actionlint_bin="$(resolve_tool actionlint)"
fi
"$actionlint_bin" -version >/dev/null 2>&1 || tool_fail "actionlint not found at $actionlint_bin"

findings=0
finding() {
  printf '%s:\n%s\n' "$1" "$2"
  findings=$((findings + 1))
}
self_rel="tests/$(basename -- "$self")"
# rgp LABEL RG_ARGS...: rg exit 1 = clean, 0 = hit (finding), >= 2 = error (finding).
rgp() {
  local label=$1 out rc=0
  shift
  out="$(rg -g "!$self_rel" "$@" 2>&1)" || rc=$?
  case "$rc" in
    0) finding "$label" "$out" ;;
    1) ;;
    *) finding "$label" "rg error (exit $rc): $out" ;;
  esac
}
# twin LABEL RG_ARGS...: positive twin; must match at least once.
twin() {
  local label=$1 out rc=0
  shift
  out="$(rg -g "!$self_rel" "$@" 2>&1)" || rc=$?
  case "$rc" in
    0) ;;
    1) finding "missing positive twin: $label" "(no match)" ;;
    *) finding "missing positive twin: $label" "rg error (exit $rc): $out" ;;
  esac
}
# yqt LABEL FILE EXPR: EXPR must evaluate to exactly `true`.
yqt() {
  local label=$1 file=$2 expr=$3 out rc=0
  out="$("$yq_bin" "$expr" "$file" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 || "$out" != true ]]; then
    finding "structure: $label" "yq '$expr' $file -> rc=$rc ${out}"
  fi
}

ci=.github/workflows/ci.yml
rel=.github/workflows/release-cockpit2.yml
for f in "$ci" "$rel"; do
  [[ -f "$f" ]] || finding "missing workflow" "$f"
done

# --- must_absent (each prints nothing) ---
rgp "HARD GATE: chmod / update-index --chmod under .github" -n 'chmod|update-index --chmod' .github
rgp "installer/script mode repair" -n 'chmod [^;|&]*(\$COCKPIT_INSTALL_ROOT/|\$cockpit_bin|bin/|install\.sh|scripts/|packaging/)' install.sh scripts
tests_out="" rc=0
tests_out="$(rg -g "!$self_rel" -n 'chmod [^;|&]*(\$COCKPIT_INSTALL_ROOT/|\$cockpit_bin|bin/|install\.sh|scripts/|packaging/)' tests 2>&1)" || rc=$?
if [[ "$rc" -ge 2 ]]; then
  finding "tests mode repair" "rg error (exit $rc): $tests_out"
elif [[ "$rc" -eq 0 ]]; then
  rc=0
  tests_out="$(rg -v '\$(fakebin|FIXTURE_FAKEBIN|stub_bin|tmpdir/fakebin)/' <<<"$tests_out" 2>&1)" || rc=$?
  if [[ "$rc" -ge 2 ]]; then
    finding "tests mode repair" "rg error (exit $rc): $tests_out"
  elif [[ -n "$tests_out" ]]; then
    finding "tests mode repair (only temp fakebin/stub fixtures may be chmod-ed)" "$tests_out"
  fi
fi
rgp "continue-on-error in ci.yml / release-cockpit2.yml" -n 'continue-on-error' "$ci" "$rel"
rgp "fail_on_unmatched_files: false" -n 'fail_on_unmatched_files: false' .github/workflows
rgp "optional / allowed-to-fail Tauri build" -n 'optional, non-blocking|tauri build[^\n]*\|\| true|--bundles [^\n]*\|\| true' .github/workflows
rgp "retired macos-13 runner" -n 'macos-13' .github/workflows
rgp "non-frozen pnpm install" -n 'pnpm install$|pnpm install --no-frozen|\|\| pnpm install' .github/workflows scripts/release-bundle.sh
rgp "hardcoded release-bundle version" -n 'COCKPIT_VERSION:-2\.' scripts/release-bundle.sh
rgp "hardcoded release-bundle target" -n 'linux-x64\.tar\.gz' scripts/release-bundle.sh
rgp "literal tauri.conf version" -n '"version": "[0-9]' app/src-tauri/tauri.conf.json
rgp "GNU coreutils on macOS runners" -n 'brew install [^#]*(coreutils|gnu-sed|findutils)' .github/workflows
rgp "secrets beyond GITHUB_TOKEN" -n -P 'secrets\.(?!GITHUB_TOKEN)' .github/workflows
rgp "codex-cockpit in release-bundle.sh" -n 'codex-cockpit' scripts/release-bundle.sh
rgp "token in an Authorization header" -n 'Authorization: (token|Bearer) \$|Bearer \$\{\{' .github
port_kill_scope=(tests .github)
for d in app/tests bench; do [[ -d "$d" ]] && port_kill_scope+=("$d"); done
for f in scripts/check-*.sh scripts/verify-release-assets.sh scripts/release-bundle.sh scripts/health-smoke.sh scripts/set-version.sh; do
  [[ -f "$f" ]] && port_kill_scope+=("$f")
done
rgp "kill by port or process name in tests/CI (fuser, lsof, p-kill, kill-all)" -n -e 'fuser\s+-k' -e 'kill\s+(-9\s+)?\$\(\s*lsof' -e 'lsof\s+-t\s+-i' -e 'p''kill\b' -e 'kill''all\b' "${port_kill_scope[@]}"
rgp "user-controlled github context in run: shell" -n '\$\{\{ *github\.(head_ref|event\.(pull_request|issue|comment|head_commit|review)[^}]*(title|body|ref|label|message|name))' .github/workflows
lint_scripts=()
for f in tests/*lint*; do [[ -f "$f" && "$f" != "$self_rel" ]] && lint_scripts+=("$f"); done
if ((${#lint_scripts[@]})); then
  rgp "scanner silent pass in a lint (stderr dropped, then or-true)" -n '2>/dev/null *\|\| true' "${lint_scripts[@]}"
fi

# --- mode drops against the C4 start commit ---
if ((copy_mode)); then
  echo "workflow-lint: note: --root copy, git mode-drop check skipped"
elif git cat-file -e "${start_sha}^{commit}" 2>/dev/null; then
  rc=0
  out="$(git diff --summary "${start_sha}..HEAD" | rg 'mode change 100755 => 100644' 2>&1)" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    finding "mode drop 100755 => 100644 since ${start_sha:0:7}" "$out"
  elif [[ "$rc" -ge 2 ]]; then
    finding "mode-drop check" "git diff | rg failed (exit $rc): $out"
  fi
elif [[ "${COCKPIT_LINT_REQUIRE_BASE:-0}" == 1 ]]; then
  finding "mode-drop check" "start commit ${start_sha} not in this clone (need full history)"
else
  echo "workflow-lint: note: start commit ${start_sha:0:7} not in this (shallow) clone; mode drops checked by check-exec-bits"
  rc=0
  out="$("$repo_root/scripts/check-exec-bits.sh" 2>&1)" || rc=$?
  [[ "$rc" -eq 0 ]] || finding "mode-drop check (check-exec-bits fallback)" "$out"
fi

# --- positive twins ---
twin "godseye-screens artifact" -n 'godseye-screens' "$ci"
twin 'exactly 3 godseye PNGs (test "$n" -eq 3)' -n 'test "\$n" -eq 3' "$ci"
twin "godseye upload fails on no files" -n 'if-no-files-found: error' "$ci"
twin "macos-15-intel in ci.yml" -n 'macos-15-intel' "$ci"
twin "macos-15-intel in release-cockpit2.yml" -n 'macos-15-intel' "$rel"
twin 'tauri.conf "version": "../package.json"' -n '"version": "\.\./package\.json"' app/src-tauri/tauri.conf.json
twin "check-exec-bits in ci.yml" -n 'check-exec-bits' "$ci"
twin "ci.yml desktop builds against the committed Cargo.lock (--locked)" -n 'pnpm tauri build --bundles "\$BUNDLES" -- --locked' "$ci"
twin "release desktop builds against the committed Cargo.lock (--locked)" -n 'pnpm tauri build --bundles "\$BUNDLES" -- --locked' "$rel"
job_lines="$(rg -c '^  shell-tests:|^  verify:|^  portability:|^  desktop:|^  versions:' "$ci" 2>&1 || :)"
[[ "$job_lines" == 5 ]] || finding "missing positive twin: 5 job lines in ci.yml" "got ${job_lines:-0}"
by_path="$(rg -c '^\s+run: \./scripts/check-exec-bits\.sh$' "$ci" 2>&1 || :)"
[[ "${by_path:-0}" -ge 2 ]] || finding "missing positive twin: ./scripts/check-exec-bits.sh run by path in versions + portability" "got ${by_path:-0}"
rgp "check-exec-bits run through bash (must run by its exec bit)" -n 'bash\s+\S*check-exec-bits' .github/workflows

# --- yq structure ---
if [[ -f "$ci" ]]; then
  yqt "ci.yml push branches keep main + cockpit-gtm-v2.3" "$ci" '.on.push.branches | contains(["main", "cockpit-gtm-v2.3"])'
  yqt "ci.yml pull_request branches keep main + cockpit-gtm-v2.3" "$ci" '.on.pull_request.branches | contains(["main", "cockpit-gtm-v2.3"])'
  for job in versions shell-tests verify portability desktop; do
    yqt "ci.yml has job $job" "$ci" ".jobs | has(\"$job\")"
  done
  for job in portability desktop; do
    yqt "ci.yml $job matrix is exactly ubuntu-latest,macos-14,macos-15-intel" "$ci" \
      ".jobs.$job.strategy.matrix.os | join(\",\") == \"ubuntu-latest,macos-14,macos-15-intel\""
  done
  yqt "ci.yml: no job-level continue-on-error" "$ci" '[.jobs[] | select(has("continue-on-error"))] | length == 0'
  yqt "ci.yml: no step-level continue-on-error" "$ci" '[.jobs[].steps[]? | select(has("continue-on-error"))] | length == 0'
  yqt "ci.yml desktop is required: no job-level if" "$ci" '.jobs.desktop | has("if") | not'
  yqt "ci.yml desktop is required: no always()/failure()/cancelled() step gates" "$ci" \
    '[.jobs.desktop.steps[] | select((.if // "") | test("always\\(|failure\\(|cancelled\\("))] | length == 0'
  yqt "ci.yml desktop runs a real tauri build" "$ci" '[.jobs.desktop.steps[] | select((.run // "") | test("pnpm tauri build"))] | length == 1'
  yqt "ci.yml desktop timeout set (<= 45 min)" "$ci" '(.jobs.desktop."timeout-minutes" <= 45) and (.jobs.desktop."timeout-minutes" > 0)'
  yqt "ci.yml desktop fail-fast false (all legs report)" "$ci" '.jobs.desktop.strategy."fail-fast" == false'
  jobs_out="$("$yq_bin" '.jobs | keys | .[]' "$ci" 2>&1)" || finding "structure: ci.yml job list" "$jobs_out"
  while IFS= read -r job; do
    [[ -n "$job" && "$job" != versions ]] || continue
    yqt "ci.yml $job needs versions" "$ci" ".jobs.\"$job\".needs // [] | [.] | flatten | contains([\"versions\"])"
  done <<<"$jobs_out"
fi
if [[ -f "$rel" ]]; then
  yqt "release: top-level permissions contents: read" "$rel" '(.permissions.contents == "read") and ([.permissions[] | select(. == "write")] | length == 0)'
  yqt "release: only publish has contents: write" "$rel" '[.jobs | to_entries[] | select(.value.permissions.contents == "write") | .key] | join(",") == "publish"'
  yqt "release: verify-assets.needs >= versions,bundle,desktop" "$rel" '.jobs."verify-assets".needs // [] | [.] | flatten | contains(["versions", "bundle", "desktop"])'
  yqt "release: publish.needs has verify-assets" "$rel" '.jobs.publish.needs // [] | [.] | flatten | contains(["verify-assets"])'
  yqt "release: publish gated to a v* tag push" "$rel" \
    "(.jobs.publish.if | test(\"github\\\\.event_name == 'push'\")) and (.jobs.publish.if | test(\"startsWith\\\\(github\\\\.ref, 'refs/tags/v'\\\\)\"))"
  yqt "release: tag trigger v2.*" "$rel" '.on.push.tags | contains(["v2.*"])'
  yqt "release: workflow_dispatch dry_run defaults to true" "$rel" '.on.workflow_dispatch.inputs.dry_run.default == true'
  yqt "release: pull_request dry run on main + cockpit-gtm-v2.3" "$rel" '.on.pull_request.branches | contains(["main", "cockpit-gtm-v2.3"])'
  yqt "release: bundle targets linux-x64,darwin-arm64,darwin-x64" "$rel" '[.jobs.bundle.strategy.matrix.include[].target] | join(",") == "linux-x64,darwin-arm64,darwin-x64"'
  yqt "release: bundle runners ubuntu-latest,macos-14,macos-15-intel" "$rel" '[.jobs.bundle.strategy.matrix.include[].os] | join(",") == "ubuntu-latest,macos-14,macos-15-intel"'
  yqt "release: desktop runners ubuntu-22.04,macos-14,macos-15-intel" "$rel" '[.jobs.desktop.strategy.matrix.include[].os] | join(",") == "ubuntu-22.04,macos-14,macos-15-intel"'
  yqt "release: no job-level continue-on-error" "$rel" '[.jobs[] | select(has("continue-on-error"))] | length == 0'
  yqt "release: no step-level continue-on-error" "$rel" '[.jobs[].steps[]? | select(has("continue-on-error"))] | length == 0'
  yqt "release: desktop runs a real tauri build" "$rel" '[.jobs.desktop.steps[] | select((.run // "") | test("pnpm tauri build"))] | length == 1'
  yqt "release: desktop timeout set (<= 45 min)" "$rel" '(.jobs.desktop."timeout-minutes" <= 45) and (.jobs.desktop."timeout-minutes" > 0)'
  yqt "release: build jobs have no if gates" "$rel" '[(.jobs.versions, .jobs.bundle, .jobs.desktop, .jobs."verify-assets") | select(has("if"))] | length == 0'
  yqt "release: gh-release fails on unmatched files" "$rel" \
    '[.jobs.publish.steps[] | select((.uses // "") | test("softprops/action-gh-release")) | .with.fail_on_unmatched_files] | .[0] == true'
fi

# --- actionlint (shellcheck integration when shellcheck is on PATH) ---
# Named quarantine, pinned to code + in-script position: two shellcheck
# warnings already present at the C4 start commit in steps C4 keeps unchanged
# (C10 godseye step's deliberate empty GODSEYE_ARCS_SHOT=, C3 portability
# suite's export PATH="$(dirname ...)"). Any other hit, or a moved one, fails.
actionlint_ignores=('SC1007:warning:9:81:' 'SC2155:warning:13:10:')
ignore_args=()
for i in "${actionlint_ignores[@]}"; do ignore_args+=(-ignore "$i"); done
echo "workflow-lint: note: actionlint quarantine (base c01379a, unchanged steps): ${actionlint_ignores[*]}"
rc=0
out="$("$actionlint_bin" -no-color "${ignore_args[@]}" .github/workflows/*.yml 2>&1)" || rc=$?
if [[ "$rc" -ne 0 ]]; then
  finding "actionlint (exit $rc)" "$out"
fi

if ((findings)); then
  printf 'workflow-lint: %s findings\n' "$findings"
  exit 1
fi
printf 'workflow-lint: 0 findings\n'
((copy_mode)) && exit 0
[[ "${COCKPIT_LINT_SELFTEST:-1}" == 1 ]] || exit 0

# --- self-test: every detector fires on a planted mutation (own label) ---
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
make_copy() {
  local dst="$scratch/$1" p
  mkdir -p "$dst/app/src-tauri"
  for p in .github install.sh scripts tests bench; do
    [[ -e "$p" ]] && cp -R "$p" "$dst/"
  done
  [[ -d app/tests ]] && cp -R app/tests "$dst/app/"
  cp app/src-tauri/tauri.conf.json "$dst/app/src-tauri/"
  printf '%s\n' "$dst"
}
# plant NAME FILE OLD NEW: literal one-shot edit (anchor must exist).
plant() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
if old not in text:
    sys.exit(f"self-test anchor not found in {path}: {old!r}")
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
}
st_pass=0 st_fail=0
# mutate NAME LABEL_REGEX FILE OLD NEW
mutate() {
  local name=$1 label=$2 file=$3 old=$4 new=$5 d out rc=0
  d="$(make_copy "$name")"
  if ! plant "$d/$file" "$old" "$new"; then
    st_fail=$((st_fail + 1))
    return 0
  fi
  out="$(COCKPIT_YQ="$yq_bin" COCKPIT_ACTIONLINT="$actionlint_bin" "$self" --root "$d" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]] && grep -Eq -- "$label" <<<"$out"; then
    printf 'workflow-lint self-test: ok   %-34s rc=%s  [%s]\n' "$name" "$rc" "$(grep -Em1 -- "$label" <<<"$out")"
    st_pass=$((st_pass + 1))
  else
    printf 'workflow-lint self-test: FAIL %-34s rc=%s (want nonzero + /%s/)\n%s\n' "$name" "$rc" "$label" "$out"
    st_fail=$((st_fail + 1))
  fi
}
ch="ch""mod"
mutate desktop-continue-on-error '^structure: ci.yml: no job-level continue-on-error' "$ci" \
  $'  desktop:\n    needs: versions\n' $'  desktop:\n    needs: versions\n    continue-on-error: true\n'
mutate step-continue-on-error '^continue-on-error in ci.yml' "$rel" \
  $'      - name: Tauri build\n' $'      - name: Tauri build\n        continue-on-error: true\n'
mutate ci-mode-repair '^HARD GATE: chmod' "$rel" \
  $'      - name: Build release bundle\n        run: ' $'      - name: Build release bundle\n        run: '"$ch"' +x scripts/x.sh && '
mutate installer-mode-repair '^installer/script mode repair' scripts/install-hostinger.sh \
  $'chown -R cockpit:cockpit "$COCKPIT_INSTALL_ROOT"\n' $'chown -R cockpit:cockpit "$COCKPIT_INSTALL_ROOT"\n'"$ch"$' +x "$COCKPIT_INSTALL_ROOT/packaging/systemd/cockpit-web-heal.sh"\n'
mutate retired-macos-13 '^retired macos-13 runner' "$ci" \
  $'  desktop:\n    needs: versions\n    runs-on: ${{ matrix.os }}\n    timeout-minutes: 45\n    strategy:\n      fail-fast: false\n      matrix:\n        os: [ubuntu-latest, macos-14, macos-15-intel]' \
  $'  desktop:\n    needs: versions\n    runs-on: ${{ matrix.os }}\n    timeout-minutes: 45\n    strategy:\n      fail-fast: false\n      matrix:\n        os: [ubuntu-latest, macos-14, macos-13]'
mutate dropped-gtm-push-trigger '^structure: ci.yml push branches keep' "$ci" \
  $'  push:\n    branches: [main, cockpit-gtm-v2.3]' $'  push:\n    branches: [main]'
mutate publish-without-verify '^structure: release: publish.needs has verify-assets' "$rel" \
  'needs: [versions, verify-assets]' 'needs: [versions]'
mutate publish-on-any-event '^structure: release: publish gated' "$rel" \
  "if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')" "if: always()"
mutate unmatched-files-ok '^fail_on_unmatched_files: false' "$rel" \
  'fail_on_unmatched_files: true' 'fail_on_unmatched_files: false'
mutate tauri-or-true '^optional / allowed-to-fail Tauri build' "$ci" \
  'run: pnpm tauri build --bundles "$BUNDLES"' 'run: pnpm tauri build --bundles "$BUNDLES" || true'
mutate extra-secret '^secrets beyond GITHUB_TOKEN' "$rel" \
  'GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}' 'GITHUB_TOKEN: ${{ secrets.RELEASE_PAT }}'
mutate tauri-literal-version '^literal tauri.conf version' app/src-tauri/tauri.conf.json \
  '"version": "../package.json"' '"version": "2.3.0-dev"'
mutate godseye-count-dropped '^missing positive twin: exactly 3 godseye PNGs' "$ci" \
  'test "$n" -eq 3' 'test "$n" -ge 1'
mutate head-ref-in-shell '^user-controlled github context' "$ci" \
  'run: ./scripts/check-versions.sh | tee' 'run: echo "${{ github.head_ref }}" && ./scripts/check-versions.sh | tee'

# Tool removal: rebuild PATH without the tool (symlink farm) and an empty cache.
# farm_run NAME LABEL DROP [KEEP_YQ]
farm_run() {
  local name=$1 label=$2 drop=$3 keep_yq=${4:-} farm="$scratch/farm-$1" cmd p out rc=0 yq_env=()
  mkdir -p "$farm/bin" "$farm/cache"
  for cmd in bash sh env git python3 curl tar gzip awk sed grep mktemp cat rm mkdir cp mv ln dirname basename \
    uname tr wc head tail sort printf find sleep ls cut id rg shellcheck stat date realpath; do
    [[ "$cmd" == "$drop" ]] && continue
    p="$(command -v "$cmd" 2>/dev/null)" || continue
    [[ "$p" == /* ]] && ln -sf "$p" "$farm/bin/$cmd"
  done
  [[ -n "$keep_yq" ]] && yq_env=(COCKPIT_YQ="$yq_bin")
  out="$(env -u COCKPIT_YQ -u COCKPIT_ACTIONLINT PATH="$farm/bin" XDG_CACHE_HOME="$farm/cache" COCKPIT_LINT_OFFLINE=1 \
    ${yq_env[@]+"${yq_env[@]}"} "$farm/bin/bash" "$self" --root "$(make_copy "$name")" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 ]] && grep -Eq -- "$label" <<<"$out"; then
    printf 'workflow-lint self-test: ok   %-34s rc=%s  [%s]\n' "$name" "$rc" "$(grep -Em1 -- "$label" <<<"$out")"
    st_pass=$((st_pass + 1))
  else
    printf 'workflow-lint self-test: FAIL %-34s rc=%s (want nonzero + /%s/)\n%s\n' "$name" "$rc" "$label" "$out"
    st_fail=$((st_fail + 1))
  fi
}
farm_run rg-missing '^workflow-lint: FAIL \(rg not found\)' rg
farm_run yq-missing '^workflow-lint: FAIL \(yq not found \(offline' none
farm_run actionlint-missing '^workflow-lint: FAIL \(actionlint not found \(offline' none keep-yq
printf 'workflow-lint self-test: %s/%s planted mutations detected\n' "$st_pass" "$((st_pass + st_fail))"
[[ "$st_fail" -eq 0 ]]
