# dotfiles

Dotfiles and installation script for my development environment. Run once on any new Mac and you're good to go.

## Quick Start

```sh
git clone https://github.com/superhighfives/dotfiles ~/Development/dotfiles
cd ~/Development/dotfiles
sh install.sh 2>&1 | tee ~/install.log
```

The script is idempotent — safe to run multiple times. It will skip anything already installed.

### Local overlays

Anything matching `*.local`, `*.local.*`, or `.*.local*` is gitignored. The tracked configs pick these up automatically so machine- or work-specific stuff stays out of the public repo. All overlays are **additive** — they layer on top of the tracked config, they don't replace it — with the one exception called out below.

| Overlay | Mechanism | Additive or replacing |
|---------|-----------|------|
| `~/.zshrc.local` | Sourced at the end of `.zshrc` | Additive (later wins for vars/aliases) |
| `~/.gitconfig.local` | `[include]` directive in `.gitconfig` | Additive (later wins) |
| `~/.config/opencode/opencode.local.jsonc` | `.zshrc` exports `OPENCODE_CONFIG` pointing at it; opencode merges with the global config | Additive (deep merge) |
| `~/Brewfile.local` | `install.sh` runs `brew bundle` against it after the main Brewfile | Additive (just installs more) |
| `~/.skills.local` | Plain-text list of skill sources read at the end of `scripts/install-skills.sh` (one `<source> [skill-csv]` per line, `#` comments OK). Each entry runs with `DISABLE_TELEMETRY=1`. | Additive (each line installs more skills) |
| `~/.pi/agent/{settings,mcp}.local.json` | `scripts/sync-pi-config.sh` deep-merges `pi/{settings,mcp}.base.json` with these into `~/.pi/agent/{settings,mcp}.json` on every `install.sh` run | Additive (deep merge; arrays concat + dedupe) |
| `~/.npmrc.local` | `install.sh` repoints `~/.npmrc` at it (npm has no include mechanism) | **Replacing** — copy anything you still want from the tracked `.npmrc` |

Drop a file into place and it gets loaded on the next shell, the next `install.sh` run, or the next `scripts/install-skills.sh` run depending on which one wraps it.

### Config tracking

`~/.config` uses an **allowlist model**: `.gitignore` drops everything under `.config/` by default (`.config/*`) and re-includes only the configs worth tracking with `!` lines. A newly installed tool that writes credentials into `.config/` is therefore ignored until you deliberately opt it in — the failure mode is "I forgot to back up a config," never "I leaked a secret to this public repo."

- **Track a new config** — add `!.config/<name>/` under the tracked list in `.gitignore`, then `git add`.
- **Keep one out for good** — add `.config/<name>/` under the acknowledged-ignores block, so it's a recorded decision rather than an accident.

Run `scripts/config-drift.sh` to audit this. It lists any `.config` entry on disk that's caught only by the blanket rule (a new tool you haven't decided about) and flags stale `!` lines pointing at paths that no longer exist. It exits non-zero when it finds drift, so it also works in a pre-commit hook or CI.

`install.sh` runs the check as a non-fatal final step, and the tracked `.githooks/pre-commit` hook runs it on every commit — advisory only (it prints drift but never blocks the commit; use `git commit --no-verify` to skip). The hook is wired up by `git config core.hooksPath .githooks`, which `install.sh` sets for you; run it by hand once in an existing clone.

## What It Does

The install script handles everything in order:

1. **Admin access** — prompts for `sudo` up front so later steps don't stall waiting for it
2. **Connectivity** — checks the internet is reachable before fetching anything
3. **Xcode CLT** — ensures Command Line Tools are installed
4. **Homebrew** — installs the package manager if missing
5. **Dotfiles repo** — clones the repo if absent, then points `core.hooksPath` at `.githooks` (enabling the pre-commit drift check)
6. **Homebrew refresh** — `brew update`/`upgrade`/`cleanup`, so deprecations and security fixes surface here rather than later
7. **Packages** — installs from `Brewfile` (always), `Brewfile.personal` (unless `--skip-personal`), and `Brewfile.local` if present
8. **Mac App Store** — installs MAS apps via `mas` (skipped if `mas` isn't available)
9. **mise** — sets up runtime version management (Node, Bun, pnpm, uv)
10. **oh-my-zsh** — installs the zsh framework
11. **Powerlevel10k** — installs the prompt theme
12. **zsh plugins** — zsh-autosuggestions, zsh-syntax-highlighting
13. **SSH** — generates an Ed25519 key and configures commit signing
14. **Dotfiles** — symlinks configs to `~` using [GNU Stow](https://www.gnu.org/software/stow/), then repoints `~/.npmrc` at `~/.npmrc.local` if present
15. **Agent skills** — runs `scripts/install-skills.sh` for shared skills, then symlinks all skills into Claude Code (`~/.claude/skills`) and OpenCode (`~/.config/opencode/commands/`)
16. **MCP servers** — registers Claude Code MCP servers (skipped if the `claude` CLI isn't installed)
17. **Secrets** — creates `~/.secrets` and prompts for your npm token
18. **Editor extensions** — Zed auto-installs extensions on first launch via `auto_install_extensions` in `.config/zed/settings.json`
19. **Raycast** — imports settings from `Raycast.rayconfig` if present
20. **Config drift** — runs `scripts/config-drift.sh` as a non-fatal check for `.config` entries git is silently ignoring

## What's Included

### Dotfiles

| File | Purpose |
|------|---------|
| `.zshrc` | Shell config — Powerlevel10k, plugins, aliases, fzf, zoxide, mise |
| `.p10k.zsh` | Powerlevel10k prompt theme |
| `.zprofile` | Shell profile (login shell setup) |
| `.gitconfig` | Git settings — delta diffs, SSH signing, color, aliases. Includes `~/.gitconfig.local` if present. |
| `.gitignore_global` | Global git ignores (macOS artifacts) |
| `.npmrc` | Public npm registry config (uses `${NPM_TOKEN}`); also sets `min-release-age=7` |
| `.bunfig.toml` | Bun global config; sets `minimumReleaseAge = 604800` (7 days) |
| `.config/pnpm/config.yaml` | pnpm global config; sets `minimumReleaseAge: 10080` (7 days) |
| `.config/uv/uv.toml` | uv global config; sets `exclude-newer = "7d"` |
| `.tool-versions` | Runtime versions for mise (Node, Bun, pnpm, uv) |
| `.ripgreprc` | Ripgrep config (smart-case, hidden files) |
| `.config/git/ignore` | Per-user git ignore patterns |
| `.config/gh/config.yml` | GitHub CLI settings |
| `.config/ghostty/config` | Ghostty terminal settings |
| `.config/opencode/opencode.json` | OpenCode AI assistant config |

| `Library/Application Support/com.pais.handy/settings_store.json` | Handy speech-to-text settings |
| `.local/bin/mount-encrypted-storage` | rclone NFS mount helper script |

### CLI Tools (via Brewfile)

| Tool | Replaces | Purpose |
|------|----------|---------|
| [bat](https://github.com/sharkdp/bat) | `cat` | Syntax-highlighted file viewer |
| [delta](https://github.com/dandavella/delta) | `diff` | Git diff viewer with syntax highlighting |
| [fd](https://github.com/sharkdp/fd) | `find` | Fast, user-friendly file finder |
| [fzf](https://github.com/junegunn/fzf) | — | Fuzzy finder for files, history, etc. |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | Very fast regex search |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Smart directory jumping |
| [htop](https://htop.dev/) | `top` | Interactive process viewer |
| [prettyping](https://github.com/denilsonsa/prettyping) | `ping` | Prettier ping output |

### Casks (macOS Apps)

**Always installed:** 1Password, Figma, Ghostty, GitHub Desktop, Google Chrome, Handy, Obsidian, OpenCode Desktop, Postman, Raycast

**Personal-only:** ChatGPT, Claude, Conductor, Discord, LM Studio, Ollama, Plex, Private Internet Access, Transmit, WhatsApp, Windows App

### Editor extensions

- `anthropic.claude-code` — Claude Code
- `astro-build.astro-vscode` — Astro
- `biomejs.biome` — Biome (linter/formatter)
- `bradlc.vscode-tailwindcss` — Tailwind CSS
- `sst-dev.opencode` — OpenCode
- `teabyii.ayu` — Ayu theme
- `unifiedjs.vscode-mdx` — MDX support

## Supply chain defense: minimum release age

Most malicious package publishes get caught and yanked within hours. To dodge that window entirely, every JS and Python package manager here is configured to refuse versions less than 7 days old. Background: [Dani Akash, "Minimum Release Age is an Underrated Supply Chain Defense"](https://daniakash.com/posts/simplest-supply-chain-defense/).

Same idea, four different config names and units, because of course:

| Tool | File | Setting |
|------|------|---------|
| npm / pnpm (auth shared) | `.npmrc` | `min-release-age=7` |
| Bun | `.bunfig.toml` | `minimumReleaseAge = 604800` (seconds) |
| pnpm | `.config/pnpm/config.yaml` | `minimumReleaseAge: 10080` (minutes) |
| uv | `.config/uv/uv.toml` | `exclude-newer = "7d"` |

pnpm v11+ already defaults to 1 day; we bump it to 7. pnpm does **not** read `min-release-age` from `.npmrc` — only auth/registry settings — so its config lives in `~/.config/pnpm/config.yaml`.

If you genuinely need a fresh release (security patch, urgent hotfix), bypass per-invocation:

```sh
npm install foo --min-release-age=0
bun install foo --minimum-release-age=0
pnpm install foo --config.minimumReleaseAge=0
uv add foo --exclude-newer=""
```

This is not a substitute for lockfiles, `--ignore-scripts` in CI, or SHA-pinned actions. It's one cheap layer of defense-in-depth.

## Skills

[Skills](https://skills.sh) are reusable instruction files (`SKILL.md`) that tell AI coding agents how to handle specific tasks. This repo manages two kinds: **local skills** authored here, and **shared skills** fetched from external sources. Both are committed to `.agents/skills/` — the difference is how they get there.

### Local skills

Custom skills live in `.agents/skills/<name>/SKILL.md` and are tracked in git. Stow symlinks the `.agents/` directory into `~/.agents/`, and `install.sh` wires them into each agent:

- **Claude Code** — `~/.claude/skills` is symlinked to `~/.agents/skills`
- **OpenCode** — each skill gets a symlink at `~/.config/opencode/commands/<name>.md` pointing back to its `SKILL.md`

To add a new local skill, drop a `SKILL.md` in `.agents/skills/<name>/` and re-run `install.sh` (the linking loop is idempotent).

### Shared skills

`scripts/install-skills.sh` uses the [`skills`](https://skills.sh) CLI to install skills globally from GitHub repos. These land in `~/.agents/skills/` alongside the local ones, so both agents pick them up automatically.

```sh
scripts/install-skills.sh                   # opencode + claude-code
scripts/install-skills.sh --skip-personal   # opencode only (work machines)
```

The default set pulls from [`vercel-labs/agent-skills`](https://github.com/vercel-labs/agent-skills). The fetched content is **committed** to `.agents/skills/` (vendored), so a fresh clone has every skill without a network fetch — and works even if an upstream repo disappears. Update everything later with `npx skills update -g`, which refreshes the folders in place; review and commit the resulting diffs.

The lock file at `.agents/.skill-lock.json` tracks installed versions but is gitignored — it can contain private skill URLs from `~/.skills.local`.

### Machine-specific skills

`~/.skills.local` adds skill sources per machine without touching the repo. One entry per line, `#` comments OK:

```
# format: <source> [skill-name ...]  (defaults to *)
github-org/internal-skills some-skill another-skill
git@gitlab.example.com:team/skills.git
```

Each line runs with `DISABLE_TELEMETRY=1`. See the [local overlays](#local-overlays) table for how this fits with the other `*.local` files.

## Post-Install (Manual Steps)

### 1. GitHub CLI

```sh
gh auth login
```

### 2. rclone (optional)

Store the entire `rclone.conf` as a secure note or document in 1Password. On the new machine, pull it out and drop it into `~/.config/rclone/`. Since 1Password is already in the Brewfile, this is the easiest path. Alternatively, run `rclone config` to set up remotes fresh.

### 3. Raycast

Export your Raycast settings and save to `Raycast.rayconfig` in the dotfiles repo. On a new machine, the install script will import them automatically.

To export: Raycast > Settings > Advanced > Export. In the export dialog, select **No password** and check only the following:

- Settings (including aliases, hotkeys & favorites)
- Extensions
- Quicklinks

Leave the rest unchecked - they're either machine-specific (AI Chats, MCP Servers, Script Directories) or potentially sensitive (Clipboard History, Raycast Notes).

### Secrets

The install script creates `~/.secrets` from `.secrets.example` and prompts for your npm token interactively. If you skip the prompt (or run non-interactively), you can fill it in later:

```sh
# ~/.secrets — sourced by .zshrc, never committed
export NPM_TOKEN="your-token-here"
```

`.npmrc` is symlinked by stow and reads `NPM_TOKEN` at runtime via `${NPM_TOKEN}`. Generate a token at [npmjs.com/settings/tokens](https://www.npmjs.com/settings/tokens).

## What I Use

- **Terminal**: [Ghostty](https://ghostty.org/)
- **Shell**: zsh + [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Editor**: [Zed](https://zed.dev) (fast editor with native AI agent panel)
- **Version manager**: [mise](https://mise.jdx.dev/)

## Updating

After making changes to dotfiles on your machine, copy them back to the repo and commit:

```sh
cd ~/Development/dotfiles
git add -A && git commit -m "Update dotfiles"
git push
```

Since stow creates symlinks, changes to `~/.zshrc` etc. are already reflected in the repo.

## Credit

Originally forked from [elithrar/dotfiles](https://github.com/elithrar/dotfiles) by Matt Silverlock.

## License

MIT. See [LICENSE](LICENSE) for details.
