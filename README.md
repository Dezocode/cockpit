# Cockpit

Status: PARTIAL. Voice CLEAR is an open residual. Owner Dezocode is away. A local read is not CLEAR. GIFs are an open residual. This pack does not add GIFs.

Cockpit is still the tmux session named `cockpit`. You attach it when Codex, Grok, Claude, or `cursor-agent` is the one typing, and a second launch joins that same session instead of starting a ghost. Version 2.3 keeps that session and puts a Tauri and React window next to it. The default checkout is `main`.

`main`, when this pack was written, is `0e7e9d62d546bf969c433c469d74361fc77c382b`, message `docs: regenerate architecture docs [skip ci]`. That commit is architecture docs on merge `0f8e56cdde8d1ee77e2d91ffa8e9c01ae3b58e5b` of pull request #40. The merge parents are `de29184552925a347edd6ae5fe4d78e83dc671b4` and `5af4f9706fda93acf074f0413a06344b1cfa40fa` (C6-next, God's Eye View onboarding). `app/package.json` and `app/src-tauri/Cargo.toml` on that tip both say `2.3.0`.

Lightweight tag `v2.3.0` is `7a099ef0c382e24011d0db3c6fe4b08d40570549`. Do not move it. The release page is <https://github.com/Dezocode/cockpit/releases/tag/v2.3.0>. Assets published from that tag are `cockpit-2.3.0-linux-x64.tar.gz`, `cockpit-2.3.0-web.tar.gz`, `cockpit-2.3.0-darwin-arm64.tar.gz`, `cockpit-2.3.0-darwin-x64.tar.gz`, `cockpit_2.3.0_amd64.deb`, `cockpit_2.3.0_amd64.AppImage`, `cockpit_2.3.0_aarch64.dmg`, `cockpit_2.3.0_x64.dmg`, and `SHA256SUMS`. A fresh Hostinger install of that tag was green. `gh_auth` is still pending. That is a C9 residual, not a C8 cell. The notify body `Cockpit v2.3.0 GTM done` was already delivered.

C6 is ahead of the published tag. `5af4f9706fda93acf074f0413a06344b1cfa40fa` and merge `0f8e56cdde8d1ee77e2d91ffa8e9c01ae3b58e5b` are on `main` and are not contained in `v2.3.0`. God's Eye View onboarding (`scripts/get-cockpit.sh`, `bin/cockpit-doctor`, `pinokio/`) lands in that range, at `5aa675c3ba7e415a4cc6e81ac8f00ce5bb9242b3`, so it is not inside the tag. Also ahead of the tag, and not C6: C9-next merge `e01792f797b5ba5d10ad0481352a199175786620` (pull request #41, `b0719b7e58444018b43afb4cd64aef343b9264a5`) and architecture-doc commits `7a87e5eaeef9593329c07919b260b7183ea493ea`, `de29184552925a347edd6ae5fe4d78e83dc671b4`, and `0e7e9d62d546bf969c433c469d74361fc77c382b`.

C5 is Laya and is on `main`. The merge is `e6e4ae2d2f59502d6c60e4b46bbea8f385163be8` (pull request #34). That commit is an ancestor of tag `v2.3.0`, so Laya is inside the tag. C5-next, the loopback listen check, is merge `60e5f3be8ec5c21902e704fa31029b15aa722f68` (pull request #39), also an ancestor of the tag.

Open the web UI and the page is a dock. The left palette has four chips, named AGENTS, COMPUTERS, FILES, and GODSEYE. Double-click GODSEYE, or drag it onto the canvas, and the panel title reads GOD'S EYE. The API default port is `8787` (`bin/cockpit-web`).

Demo: [docs/demo-v2.3.md](docs/demo-v2.3.md). Notes: [docs/release-notes-v2.3.0-draft.md](docs/release-notes-v2.3.0-draft.md). Install body: [packaging/release/release-body.md](packaging/release/release-body.md).

tmux workspace for local coding agents (Codex, Grok, Anthropic, Cursor).
Public repo: **https://github.com/Dezocode/cockpit**. Tokens never go in git.

## Cockpit 2 (GUI — parallel upgrade)

Tauri 2 + React web IDE alongside the tmux TUI (zero regression). Product name
**cockpit** only.

```bash
./install.sh                              # TUI (unchanged)
COCKPIT_INSTALL_WEB_BUILD=1 ./install.sh  # + web build
cockpit-web                               # API on :8787
curl -s localhost:8787/api/health | jq .
```

Hostinger + grok-build subscription lane (install root `/opt/cockpit`, ≠ Saul):

```bash
sudo ./scripts/install-hostinger.sh        # canonical deploy (single script)
./scripts/hostinger-health.sh --wait 30    # GET /api/health probe (waits up to 30s)
```

Health probe: `GET /api/health` — see [deploy/README.md](deploy/README.md)
Env vars each launcher, plist and unit sets: [docs/service-env.md](docs/service-env.md)


## Onboarding (keyless-first)

This section is C6. It is on `main` and it is not inside tag `v2.3.0`.

Modeled on [God's Eye View](https://github.com/bilawalsidhu/gods-eye-view) distribution (Pinokio + one-command install + in-app POWER UP). Credit: Bilawal Sidhu, MIT code only.

### Path 1 — Pinokio (one click)

Open this repo in [Pinokio](https://pinokio.computer) ≥ 8.2, click **Install**, then **Start**. Sharing stays forced off.

### Path 2 — One command (terminal)

```bash
# From a checkout (CI / local):
bash scripts/get-cockpit.sh --from-dir "$PWD"
cockpit doctor --json
```

`scripts/get-cockpit.sh` is on `main` and is not in tag `v2.3.0`. The published release already has `SHA256SUMS`; this curl reads the script from `main`, not from the tag:

```bash
curl -fsSL https://raw.githubusercontent.com/Dezocode/cockpit/main/scripts/get-cockpit.sh | bash
```

### Paste this into your coding agent

```
Set up Cockpit from https://github.com/Dezocode/cockpit. Check prerequisites with `cockpit doctor`, install with `bash scripts/get-cockpit.sh --from-dir .` (or `./install.sh`), and launch the default keyless version (`cockpit` or `cockpit-web`). Keep API keys local; don't ask me to paste them into this chat. Use `cockpit keys set <id>` or the in-app SETUP → KEYS panel (POWER UP) on loopback only.
```

### Then power it up — in the app, not in a file

Open SETUP → KEYS. Add a provider key; the page only ever shows `set ✓`. On Hostinger, set keys over SSH with `cockpit keys set`.

## Notifications

Ship-time human ping (Telegram via Hermes or server-side Bot API token, ntfy fallback, desktop toast):

```bash
cockpit notify "Cockpit v2.3.0 GTM done"
```

Tokens live only on the Hostinger host (`/etc/cockpit/notify.env`), never in git or the browser bundle. See [docs/notify.md](docs/notify.md).

## Laya-first routing (optional)

C5. On `main`, and an ancestor of tag `v2.3.0` (`e6e4ae2d2f59502d6c60e4b46bbea8f385163be8`).

Local [Laya](https://pypi.org/project/laya/) can pick tier + runtime before launch (`cockpit laya install`, `cockpit laya start`, `cockpit route --launch "task"`). Loopback-only sidecar; routing is off when Laya is absent, disabled, or `COCKPIT_LAYA=0`. Receipts store task SHA-256 only (`~/.local/state/cockpit/route.jsonl`).

The browser terminal (`/ws/pty`) requires GitHub sign-in — no shared tokens.
Operator setup (OAuth app + allowlist): [docs/terminal-auth.md](docs/terminal-auth.md).
Until it is configured, the terminal refuses all connections (fail-closed).

Release: [v2.3.0](https://github.com/Dezocode/cockpit/releases/tag/v2.3.0) (`7a099ef`; `main` is ahead) · [v2.2.2](RELEASE_NOTES_v2.2.2.md) · [v2.2.0 visual multiview](RELEASE_NOTES_v2.2.0.md) · gospel: [t10u visual multiview](bench/cursor/reports/t10u-cockpit-visual-multiview-gospel.md) · matrix: `./bench/cockpit/capability-matrix.sh` · proofs: `proofs/t72u/t384u-live-spa/` · Canon map: `tmp/t847u/README.md`

## New machine (for a human or an agent)

Fork or clone **this** repo — not someone else's private files. Then on the
new computer:

```bash
git clone https://github.com/Dezocode/cockpit.git
cd cockpit
./install.sh
gh auth login -h github.com -p https -w   # HER GitHub account
cockpit config pull                        # optional: HER gist only
cockpit                                    # filtered interactive attach
cockpit agent                               # reattach safely from Termius
```

Needs: `tmux`, and whichever agent CLIs she wants (`codex`, `grok`, `claude`,
`cursor-agent`). On macOS also install Homebrew `bash` (≥4), `fswatch`, and
`tmux` (`brew install bash tmux fswatch`). Each CLI keeps its own login on
**that** machine. The public
tree has templates only — no API keys, no `auth.json`, no gists from other
people. `cockpit config push` writes a **secret gist on the signed-in `gh`
user**, never into this git repo.

One tmux session named `cockpit`. A second launch attaches that runtime;
leftover `cockpit-*` sessions with no clients are reaped so ghost Codex
processes do not accumulate. Existing `codex-cockpit` sessions are accepted
and upgraded in place.

One tmux workspace, two equal profiles, switched live:

Keyboard and click always work. After idle, the next **key** remembers
desktop chrome and is forwarded to the agent; the next **tap** remembers
touch chrome and still selects the pane. Until that input, the last config
stays. Typing while you are active is never intercepted.

Endpoint size still wins for fit: phone-sized clients stay on tabs.

| Profile | Detected when | Chrome |
| --- | --- | --- |
| **Foot / Omarchy** | local Foot, `xdg-terminal-exec`, Wayland | 2×2 pad, status top, prefix `Ctrl-Space` |
| **Termius iOS** | iPhone SSH footprint (Tailscale `100.64/10`, `tailscaled`→`login`, no `COLORTERM`, or `TERM_PROGRAM=Termius`) | full-screen tabs, status bottom, prefix `Ctrl-B`, F1–F6, long-press menu |

Local Foot wins if both clients are attached, so the Omarchy pad is not crushed by a 54-column phone.

Views (same in both profiles):

- **AGENT** — live runtime, approvals, applied edits
- **FILES** — Neovim, following files Codex just wrote
- **DIFF** — scoped, event-driven patch; optional Vim diff view
- **MAP** — browserless Mermaid with a local Show Me graph adapter
- **SETUP** — persistent terminal flow for auth, Agent switching, Git targets, plugins, and audit
- **PRS** — GitHub PRs

The AGENT pane launches the native Codex CLI with inherited no-color/CI
switches cleared and truecolor negotiated through tmux. If `codex` is a
write-on-start mise shim, Cockpit uses the newest already-installed Codex
binary instead; set `CODEX_CLI_BIN` to override that choice. DIFF separates
staged, working-tree, and untracked patches, with readable red/green bands;
`COCKPIT_DIFF_ADD_BG` and `COCKPIT_DIFF_DELETE_BG` can override those colors.
Use `prefix + V` or the pane menu's **Vim diff** entry for an on-demand,
read-only Neovim/Vim two-pane diff. It opens one changed file at a time, so
the resident DIFF watcher stays event-driven and cheap.
The tmux status-right label is the Git worktree name, branch, and live state
(`✓` clean or `!` dirty); the runtime selector still keeps the provider name.

FILES, DIFF, MAP, and the runtime chrome read the active Omarchy
`colors.toml`, so Git additions/removals and Neovim diff bands follow the
current Foot palette. A project-shaped directory without a Git root is
initialized automatically for those tabs; set `COCKPIT_GIT_INIT=0` to opt out.
MAP uses the local `cockpit-showmegraphs` adapter by default. It prefers
the existing `mermaid-ascii` or `merman-cli` renderer and falls back to the
Mermaid source without starting a background process. Set
`COCKPIT_MAP_RENDERER=raw` to force source view.

```bash
cockpit
```

After installation, `cpr` runs the Cockpit-native `cockpit.cpr` plugin. It
validates the overlay, applies only idempotent session options/hooks, and
refreshes the Agent toolbar with a signal. The live Agent, FILES, SETUP, DIFF,
and MAP pane processes are preserved:

```bash
cpr
cpr --check                 # plan only; no live tmux changes
cockpit plugin list         # Cockpit-native plugins, not Codex plugins
```

`cpr` does not create a tmux server or session when one is absent. That is the
main reason a transient “server exited” message can appear: tmux has no
session to keep alive, or an older reload path is respawning the last useful
pane during an attach race. Run `cockpit /path/to/project` to create the
canonical session, then use `cpr --check` to inspect it. The optional
`--refresh-derived` flag is the only CPR mode that permits DIFF/MAP respawns;
it is disabled by default. Configure the behavior in
`~/.config/cockpit/cockpit.conf`:

```ini
[cpr]
overlay=1
hooks=1
agent_validation=1
refresh_bar=signal
adapt_layout=0
refresh_derived=0
ensure_bar=0
```

`cockpit` attaches the tmux workspace. `cockpit agent` jumps to the live
Agent pane when tabs or chips stop responding. `codex` is the Codex CLI.
The workspace is displayed as **COCKPIT**; its canonical tmux session is
`cockpit` (legacy `codex-cockpit` sessions are upgraded automatically). On the **AGENT** page, fat **PRS / provider /
MODEL / RESTART** buttons sit above the live Agent. **PRS** opens the PR page,
the provider button opens the persistent **SETUP** flow, and **MODEL** opens
the shared provider/model picker in **SETUP**. Its OAuth indicators are local
CLI checks. In SETUP, `a` starts configured OAuth in-pane, `p` changes the
live Agent CLI, `m` opens the model catalog, `g` selects a target project,
`i` initializes that target after confirmation, `l` browses/installs a selected
Codex marketplace plugin, `u` runs a read-only Cockpit audit, `v` validates the
active provider's `.codex`/`.agent` project target, `k` previews and confirms
user-profile skill additions, and `e` opens
`~/.config/cockpit/providers.conf` in Vim. The top chips use these same
in-pane flows; they do not open a second desktop popup.

Cockpit also has its own provider-aware profile layer. It detects project-local
`.codex`, `.agent`, `.agents`, `AGENTS.md`, and provider convention files, then records the
currently stationed provider's selected target in tmux metadata. Add optional
user skills as Markdown files under
`~/.config/cockpit/skills.d/`; SETUP `v` validates the target and `k`
previews and asks before adding a managed `cockpit-profile` block. Existing
instructions are kept, updates are atomic, and a timestamped backup is made.
The standalone validator is safe by default:

```bash
cockpit profile detect --session cockpit
cockpit profile validate --session cockpit
cockpit profile apply /path/to/project codex       # dry run
cockpit profile apply --yes /path/to/project codex # confirmed write
```

Provider files may override detection with `agent_file=`, `agent_files=`, or
`agent_paths=`. The hook is read-only and runs on Cockpit attach/window/provider
events, so validation follows the provider currently occupying AGENT. The
Cockpit profile plugin is not a Codex marketplace plugin; `l` remains the
separate native Codex plugin flow.

`prefix + R` (or
long-press → Restart runtime) relaunches the
active provider in the same pane with the current color environment. `prefix + e`
(or F7, or tap the provider button) opens a tmux Agent picker with a list of
runtimes (Codex, Grok, Anthropic/claude, Cursor). After you pick one it asks
**switch active** (pause the other, save compute) or **parallel tab** (both
keep running). `o` opens Omarchy's native default-Agent switcher. OAuth stays
with each CLI.

The SETUP MODEL picker reads optional `models=` values or a bounded,
on-demand `models_command=` from each runtime provider. A provider without
either entry is shown with a native-picker option, so Cockpit never guesses
or silently probes a provider. An optional `model_apply=` command receives
`COCKPIT_PROVIDER` and `COCKPIT_MODEL` when a provider needs a custom apply
step.

The runtime picker also includes **Open Source (gpt-oss)**. It launches the
native Codex TUI with `codex --oss`; Codex uses a configured LM Studio or
Ollama provider for the local model.

Desktop Foot uses a click-out overlay box. Termius iOS cannot paint that overlay,
so the same command opens as a full tab; **q / Esc / success / tap AGENT**
closes it and returns to the agent. Tokens never go in git. The public tree is
**https://github.com/Dezocode/cockpit** (live as soon as it is pushed — GitHub
does not wait for you to reopen the page; search `cockpit`, not only
`codex-cockpit`).

For Termius, enable **Send mouse events** and enter through `cockpit` (or
`cockpit agent`). Those attach commands use the bundled PTY bridge to
repair Termius' negative-row SGR packets before tmux sees them; the toolbar is
then four full-width touch zones above AGENT, and the bottom tabs remain the
canonical page navigation.

From Omarchy/Foot:

```bash
omarchy launch tui cockpit
```

`Super+Alt+C` launches the cockpit in Foot. `Super+Alt+K` is Omarchy's tmux key list. `codex-cli` is the raw CLI.

`prefix + k` forces desktop/keyboard. `prefix + t` forces touch/mobile.
`prefix + A` opens a nested auth box from `~/.config/cockpit/providers.conf`
(GitHub is `gh auth login` web OAuth). Click outside the box to cancel; it
closes after success. SETUP uses `gh auth status -h github.com`, `codex login
status`, and a structured Grok OIDC cache check, so a stale auth file is not
reported as ready. SETUP `l` lists available Codex marketplace plugins and
installs only the entry you select and confirm. `cockpit audit` checks
the same provider states plus the live tmux topology without printing secrets.

Watchers stay blocked on inotify while idle. Hidden or zoomed-away views only set a dirty bit; the visible pad (Foot) or the open tab (Termius) refreshes after a coalesced burst of file events. Detached idle only keeps profile state on disk (`~/.config/cockpit/state`).

## Install

```bash
./install.sh
```

Requires tmux, a Codex CLI on `PATH`, and (for PRs) GitHub CLI. Local CLI auth
is used as-is (`gh auth status`, `codex login status`, Grok's local OIDC
cache, `claude auth status`, `cursor-agent status`). Already signed in → no
prompt.
Unsigned providers get one nested box (click out to skip). Background panes
do not ring the terminal (Termius haptics stay off).

Unsigned `gh` does not block the Codex runtime; the PR pane and `prefix + G`
open that same nested box.

## Your profile vs this repo

CLI tokens (`gh`, Codex, Grok, Claude, Cursor) stay on **your** machine and
your **your** GitHub login. They are not in this git tree.

Save or restore *chrome + provider command templates* with the same `gh`
account you already use:

```bash
cockpit config status
cockpit config push    # secret gist on *your* GitHub account
cockpit config pull    # from that gist
```

`push` refuses files that look like tokens. `~/.codex/auth.json` and
`~/.grok/auth.json` are never uploaded.

## License

MIT. Do not commit API tokens, `~/.codex/auth.json`, or Grok credentials.
