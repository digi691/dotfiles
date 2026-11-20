# oh-my-zsh lives in its own default location ($HOME/.oh-my-zsh) rather than
# inside this repo — it's a large external project installed by
# lib/install-omz.sh, not something we vendor. ZSH_THEME is intentionally
# blank: Starship (see bootstrap.zsh) renders the prompt instead.
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
export ZSH_THEME=""
export DISABLE_AUTO_UPDATE="true"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
)

[ -d "$ZSH" ] && source "$ZSH/oh-my-zsh.sh"
