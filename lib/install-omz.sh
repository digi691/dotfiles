#!/usr/bin/env bash
# Installs oh-my-zsh and its plugins without letting the omz installer touch
# ~/.zshrc — we manage that file ourselves via lib/inject-rc.sh.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/lib/pkg.sh"

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

if [ ! -d "$ZSH" ]; then
  echo "==> Installing oh-my-zsh to $ZSH"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

plugin_repo() {
  name="$1"; url="$2"
  dest="$ZSH_CUSTOM/plugins/$name"
  if [ ! -d "$dest" ]; then
    echo "==> Installing zsh plugin: $name"
    git clone --depth=1 "$url" "$dest"
  fi
}

plugin_repo zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
plugin_repo zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
plugin_repo zsh-completions https://github.com/zsh-users/zsh-completions
