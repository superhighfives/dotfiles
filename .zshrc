# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
  colored-man-pages
  command-not-found
  git
  uv
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# --- Secrets (conditional) ---
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"

# --- Homebrew ---
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if command -v brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# --- Editor ---
code() {
  if command -v windsurf &>/dev/null; then
    windsurf "$@"
  else
    nano "$@"
  fi
}

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
elif command -v windsurf &>/dev/null; then
  export EDITOR='windsurf --wait'
else
  export EDITOR='nano'
fi

# --- SSH ---
# Load SSH keys from macOS Keychain (adds key if passphrase is cached in Keychain)
if [[ -f ~/.ssh/id_ed25519 ]]; then
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null
fi

# --- Aliases ---
command -v bat &>/dev/null && alias cat='bat'
command -v prettyping &>/dev/null && alias ping='prettyping --nolegend'
command -v htop &>/dev/null && alias top='sudo htop'

command -v eza &>/dev/null && alias ls='eza --icons --group-directories-first'
command -v eza &>/dev/null && alias ll='eza -l --header --icons --git'
command -v eza &>/dev/null && alias la='eza -la --icons'
command -v eza &>/dev/null && alias lt='eza --tree --level=2'

command -v rg &>/dev/null && alias grep='rg'

# --- fzf (fuzzy finder) ---
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --reverse --border --preview "bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || ls -la {}" --bind="ctrl-o:execute(code {})+abort"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS='--preview "ls -la {}"'
source <(fzf --zsh 2>/dev/null) || { [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh; }
alias pv="fzf --preview 'bat --color always {}'"
bindkey "ç" fzf-cd-widget

_fzf_comprun() {
  local command=$1
  shift
  case "$command" in
    cd) fzf "$@" --preview 'tree -C {} | head -200' ;;
    *)  fzf "$@" ;;
  esac
}

# --- atuin (shell history) ---
# Must come after fzf so atuin owns ctrl+r. Config lives in ~/.config/atuin/config.toml.
if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh)"
fi

# --- zoxide (smart cd) ---
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# --- mise (runtime version manager) ---
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
elif command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

# --- ripgrep ---
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

# --- uv (supply chain defense: 1-day minimum release age) ---
export UV_EXCLUDE_NEWER="$(date -u -v-1d '+%Y-%m-%dT%H:%M:%SZ')"

# --- PATH ---
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# LM Studio (conditional)
[[ -d "$HOME/.lmstudio/bin" ]] && export PATH="$PATH:$HOME/.lmstudio/bin"

# gs
func gs() {
  git switch $(git for-each-ref --sort=-committerdate --format='%(refname:short)' 'refs/heads/**' | fzf --preview='git log main..{}')
}

# --- rclone mount aliases (conditional) ---
if command -v rclone &>/dev/null; then
  alias mount-brightly='mount-encrypted-storage brightly'
  alias mount-general='mount-encrypted-storage general'
  alias mount-titan='mount-encrypted-storage titan'
fi

# --- Powerlevel10k ---
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# opencode local overlay (auto-loads if present)
[[ -f ~/.config/opencode/opencode.local.jsonc ]] && \
  export OPENCODE_CONFIG="$HOME/.config/opencode/opencode.local.jsonc"

# Local overlay (untracked, machine-specific)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
