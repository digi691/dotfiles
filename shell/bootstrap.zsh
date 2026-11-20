# Sourced from ~/.zshrc. Guarded so it's harmless to source twice.
[ -n "$_DOTFILES_ZSH_BOOTSTRAPPED" ] && return
_DOTFILES_ZSH_BOOTSTRAPPED=1

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

source "$DOTFILES_DIR/shell/common/os-detect.sh"
source "$DOTFILES_DIR/shell/common/path.sh"
source "$DOTFILES_DIR/shell/common/aliases.sh"
source "$DOTFILES_DIR/shell/zsh/options.zsh"
source "$DOTFILES_DIR/shell/zsh/omz.zsh"

# Starship renders the prompt, not oh-my-zsh's theme system (see omz.zsh).
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

[ -f "$DOTFILES_DIR/shell/local.zsh" ] && source "$DOTFILES_DIR/shell/local.zsh"
