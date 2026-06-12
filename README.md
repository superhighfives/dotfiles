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

Files ending in `.local` are untracked machine-specific overlays. They live directly in `~/` and the tracked dotfiles pick them up automatically:

- `~/.zshrc.local` - sourced at the end of `.zshrc`.
- `~/.gitconfig.local` - included from `.gitconfig`.
- `~/.npmrc.local` - if present, `install.sh` overrides `~/.npmrc` to point at it (npm has no include mechanism).
- `~/.config/opencode/opencode.local.jsonc` - `.zshrc` exports `OPENCODE_CONFIG` pointing at it if present, so opencode merges it with the global config.
- `~/Brewfile.local` - `install.sh` runs it after the main `Brewfile` if it exists.

The public repo stays clean. Drop a file into place and it gets loaded.

## What It Does

The install script handles everything in order:

1. **Xcode CLT** — ensures Command Line Tools are installed
2. **Homebrew** — installs the package manager if missing
3. **Packages** — installs from `Brewfile` (always), `Brewfile.personal` (unless `--skip-personal`), and `Brewfile.local` if present
4. **mise** — sets up runtime version management (Node, Bun, pnpm, uv)
5. **oh-my-zsh** — installs zsh framework with Powerlevel10k theme
6. **Plugins** — zsh-autosuggestions, zsh-syntax-highlighting
7. **SSH** — generates an Ed25519 key and configures commit signing
8. **Dotfiles** — symlinks configs to `~` using [GNU Stow](https://www.gnu.org/software/stow/)
9. **Secrets** — creates `~/.secrets` and prompts for your npm token
10. **Extensions** — Zed auto-installs extensions on first launch via `auto_install_extensions` in `.config/zed/settings.json`
11. **Raycast** — imports settings from `Raycast.rayconfig` if present

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
| `.ssh/config` | SSH hosts and settings |
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
