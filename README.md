# dotfiles

Dotfiles and installation script for my development environment. Run once on any new Mac and you're good to go.

## Quick Start

```sh
git clone https://github.com/superhighfives/dotfiles ~/Development/dotfiles
cd ~/Development/dotfiles
sh install.sh 2>&1 | tee ~/install.log
```

The script is idempotent — safe to run multiple times. It will skip anything already installed.

## What It Does

The install script handles everything in order:

1. **Xcode CLT** — ensures Command Line Tools are installed
2. **Homebrew** — installs the package manager if missing
3. **Packages** — installs CLI tools and apps from `Brewfile`
4. **mise** — sets up runtime version management (Node, Bun, pnpm, uv)
5. **oh-my-zsh** — installs zsh framework with Powerlevel10k theme
6. **Plugins** — zsh-autosuggestions, zsh-syntax-highlighting
7. **SSH** — generates an Ed25519 key and configures commit signing
8. **Dotfiles** — symlinks configs to `~` using [GNU Stow](https://www.gnu.org/software/stow/)
9. **Secrets** — creates `~/.secrets` and prompts for your npm token
10. **Extensions** — installs VS Code / Cursor extensions
11. **Raycast** — imports settings from `Raycast.rayconfig` if present

## What's Included

### Dotfiles

| File | Purpose |
|------|---------|
| `.zshrc` | Shell config — Powerlevel10k, plugins, aliases, fzf, zoxide, mise |
| `.p10k.zsh` | Powerlevel10k prompt theme |
| `.zprofile` | Shell profile (OrbStack integration) |
| `.gitconfig` | Git settings — delta diffs, SSH signing, color, aliases |
| `.gitignore_global` | Global git ignores (macOS artifacts) |
| `.tool-versions` | Runtime versions for mise (Node, Bun, pnpm, uv) |
| `.ripgreprc` | Ripgrep config (smart-case, hidden files) |
| `.ssh/config` | SSH hosts and settings |
| `.config/git/ignore` | Per-user git ignore patterns |
| `.config/gh/config.yml` | GitHub CLI settings |
| `.config/ghostty/config` | Ghostty terminal settings |
| `.config/opencode/opencode.json` | OpenCode AI assistant config |
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

1Password, ChatGPT, Claude, Conductor, Cursor, Discord, Figma, Fork, Ghostty, GitHub Desktop, Google Chrome, LM Studio, Obsidian, Ollama, OpenCode Desktop, OrbStack, Plex, Postman, Raycast, Tailscale, Transmit, WhatsApp, Windows App

### VS Code / Cursor Extensions

- `anthropic.claude-code` — Claude Code
- `astro-build.astro-vscode` — Astro
- `biomejs.biome` — Biome (linter/formatter)
- `bradlc.vscode-tailwindcss` — Tailwind CSS
- `sst-dev.opencode` — OpenCode
- `teabyii.ayu` — Ayu theme
- `unifiedjs.vscode-mdx` — MDX support

## Post-Install (Manual Steps)

### 1. GitHub CLI

```sh
gh auth login
```

### 2. rclone (optional)

Store the entire `rclone.conf` as a secure note or document in 1Password. On the new machine, pull it out and drop it into `~/.config/rclone/`. Since 1Password is already in the Brewfile, this is the easiest path. Alternatively, run `rclone config` to set up remotes fresh.

### 3. Raycast

Export your Raycast settings and save to `Raycast.rayconfig` in the dotfiles repo. On a new machine, the install script will import them automatically. To export: Raycast > Settings > Advanced > Export.

### Secrets

The install script creates `~/.secrets` from `.secrets.example` and prompts for your npm token interactively. If you skip the prompt (or run non-interactively), you can fill it in later:

```sh
# ~/.secrets — sourced by .zshrc, never committed
export NPM_TOKEN="your-token-here"
```

`.npmrc` is symlinked by stow and reads `NPM_TOKEN` at runtime via `${NPM_TOKEN}`. Generate a token at [npmjs.com/settings/tokens](https://www.npmjs.com/settings/tokens).

## What I Use

- **Terminal**: [Ghostty](https://ghostty.org/) / [OrbStack](https://orbstack.dev/) for containers
- **Shell**: zsh + [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Editor**: [Cursor](https://cursor.sh/) (VS Code fork)
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
