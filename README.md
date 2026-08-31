# Cockpit

tmux workspace for local coding agents (Codex, Grok, Anthropic, Cursor).
Public repo: **https://github.com/Dezocode/cockpit**. Tokens never go in git.

## New machine (for a human or an agent)

Fork or clone **this** repo — not someone else's private files. Then on the
new computer:

```bash
git clone https://github.com/YOUR_USER/cockpit.git
cd cockpit
./install.sh
gh auth login -h github.com -p https -w   # HER GitHub account
cockpit config pull                        # optional: HER gist only
cockpit                                    # or: tmux attach -t codex-cockpit
```

Needs: `tmux`, and whichever agent CLIs she wants (`codex`, `grok`, `claude`,
`cursor-agent`). Each CLI keeps its own login on **that** machine. The public
tree has templates only — no API keys, no `auth.json`, no gists from other
people. `cockpit config push` writes a **secret gist on the signed-in `gh`
user**, never into this git repo.

One tmux session named `codex-cockpit`. A second launch attaches that
runtime; leftover `codex-cockpit-*` sessions with no clients are reaped so
ghost Codex processes do not accumulate.

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
- **SETUP** — persistent terminal flow for OAuth, Agent switching, and Git targets
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
MAP uses the local `codex-cockpit-showmegraphs` adapter by default. It prefers
the existing `mermaid-ascii` or `merman-cli` renderer and falls back to the
Mermaid source without starting a background process. Set
`COCKPIT_MAP_RENDERER=raw` to force source view.

```bash
cockpit
```

After installation, `cpr` reloads the Cockpit tmux overlay, the Agent button
bar, and the DIFF/MAP views, creating SETUP if needed. Existing Agent, FILES,
and SETUP flow processes stay running:

```bash
cpr
```

`cockpit` attaches the tmux workspace. `cockpit agent` jumps to the live
Agent pane when tabs or chips stop responding. `codex` is the Codex CLI.
The workspace is displayed as **COCKPIT**; its stable internal tmux session
remains `codex-cockpit`. On the **AGENT** page, fat **PRS / provider /
MODEL / RESTART** buttons sit above the live Agent. **PRS** opens the PR page,
the provider button opens the persistent **SETUP** flow, and **MODEL** opens
the shared provider/model picker in **SETUP**. Its OAuth indicators are local
CLI checks. In SETUP, `a` starts configured OAuth in-pane, `p` changes the
live Agent CLI, `m` opens the model catalog, `g` selects a target project,
`i` initializes that target after confirmation, and `e` opens
`~/.config/codex-cockpit/providers.conf` in Vim. The top chips use these same
in-pane flows; they do not open a second desktop popup.
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

From Omarchy/Foot:

```bash
omarchy launch tui codex-cockpit
```

`Super+Alt+C` launches the cockpit in Foot. `Super+Alt+K` is Omarchy's tmux key list. `codex-cli` is the raw CLI.

`prefix + k` forces desktop/keyboard. `prefix + t` forces touch/mobile.
`prefix + A` opens a nested auth box from `~/.config/codex-cockpit/providers.conf`
(GitHub is `gh auth login` web OAuth). Click outside the box to cancel; it
closes after success. Add more `[provider]` blocks for other sources — Codex
CLI and Grok logins stay with those tools and are not listed by default.

Watchers stay blocked on inotify while idle. Hidden or zoomed-away views only set a dirty bit; the visible pad (Foot) or the open tab (Termius) refreshes after a coalesced burst of file events. Detached idle only keeps profile state on disk (`~/.config/codex-cockpit/state`).

## Install

```bash
./install.sh
```

Requires tmux, a Codex CLI on `PATH`, and (for PRs) GitHub CLI. Local CLI auth is used as-is (`gh`, `~/.codex/auth.json`, `~/.grok/auth.json`,
`claude auth status`, `cursor-agent status`). Already signed in → no prompt.
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
