# ~/.zshenv — sourced by EVERY zsh invocation (interactive, non-interactive,
# scripts, and processes that inherit this shell's env). Keep this minimal:
# only the PATH/env that *all* contexts need. Interactive niceties (prompt,
# plugins, completions, `mise activate` hook) stay in .zshrc.
#
# This is what makes node/npx/mise resolve in non-interactive contexts — the
# Claude Code Bash tool, scripts, and (when the editor is launched from a
# terminal) MCP servers — without those contexts having to source .zshrc.

# Homebrew (so brew-installed tools are on PATH everywhere).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# User-local bins (where the mise binary itself and other user tools live).
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# mise shims — the supported way to expose mise-managed runtimes (node, pnpm,
# …) to non-interactive shells. Prepended so mise wins over system/brew copies.
# .zshrc additionally runs `mise activate zsh` for the interactive cd-hook.
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi
