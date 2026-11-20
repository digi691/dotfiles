# Sourced from ~/.bashrc and/or ~/.bash_profile. Guarded so it's harmless to source twice
# (e.g. .bash_profile sourcing .bashrc).
[ -n "$_DOTFILES_BASH_BOOTSTRAPPED" ] && return
_DOTFILES_BASH_BOOTSTRAPPED=1

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# Hand the interactive session off to zsh, mirroring the classic
# `exec /bin/zsh` pattern — but safely: only for interactive shells, only if
# zsh is actually installed, and skippable with DOTFILES_NO_EXEC_ZSH=1.
if [[ $- == *i* ]] && [ -z "$DOTFILES_NO_EXEC_ZSH" ] && [ -z "$ZSH_VERSION" ]; then
  if command -v zsh >/dev/null 2>&1; then
    exec zsh -l
  fi
fi

# --- Reached only when zsh is unavailable/disabled: configure bash itself ---
source "$DOTFILES_DIR/shell/common/os-detect.sh"
source "$DOTFILES_DIR/shell/common/path.sh"
source "$DOTFILES_DIR/shell/common/aliases.sh"
source "$DOTFILES_DIR/shell/bash/fallback.bash"

[ -f "$DOTFILES_DIR/shell/local.bash" ] && source "$DOTFILES_DIR/shell/local.bash"
