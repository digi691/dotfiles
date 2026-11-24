#!/usr/bin/env bash
# Brings an existing install up to date. Unlike install.sh (which skips
# anything already present), this always tries to move each piece forward.
#
# Scope: only touches what this repo manages directly — Homebrew formulas
# it installed, Starship, oh-my-zsh + its plugins, vim-plug, TPM. If a tool
# came from the system-package fallback (DOTFILES_NO_BREW=1), update it
# through your OS's normal update process instead — this deliberately
# doesn't run a system-wide apt/pacman/dnf upgrade on your behalf.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
source "$DOTFILES_DIR/lib/pkg.sh"

if dotfiles_has brew; then
  echo "==> Updating Homebrew + formulas"
  # Tolerate failure here the same way dotfiles_install does for a fresh
  # install: brew itself can be present but unable to actually update/
  # install formulas (e.g. Homebrew's Linux x86_64 support refuses to run
  # under an emulator lacking SSSE3) — that shouldn't take down the rest
  # of this script's updates (Starship, oh-my-zsh, vim/tmux plugins).
  (brew update && brew upgrade) || echo "    brew update/upgrade failed, continuing"
else
  echo "==> Homebrew not installed here, skipping brew upgrade"
fi

if [ -f "$HOME/.local/bin/starship" ]; then
  echo "==> Updating Starship (local installer)"
  curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$HOME/.local/bin" -y
fi

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [ -d "$ZSH" ]; then
  echo "==> Updating oh-my-zsh"
  if [ -f "$ZSH/tools/upgrade.sh" ]; then
    ZSH="$ZSH" sh "$ZSH/tools/upgrade.sh" || true
  else
    git -C "$ZSH" pull --ff-only || true
  fi

  ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
    dir="$ZSH_CUSTOM/plugins/$plugin"
    if [ -d "$dir" ]; then
      echo "==> Updating zsh plugin: $plugin"
      git -C "$dir" pull --ff-only || true
    fi
  done
fi

if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
  echo "==> Updating vim-plug + vim plugins"
  curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  vim +PlugUpdate +qall || true
fi

if [ -x "$HOME/.tmux/plugins/tpm/bin/update_plugins" ]; then
  echo "==> Updating tmux plugins"
  "$HOME/.tmux/plugins/tpm/bin/update_plugins" all || true
fi

# Only re-download kubectl/k9s/kubelogin if that's how they're actually
# managed here (~/.local/bin) — if they came from brew or the system
# package manager instead, the steps above/your OS already cover updating
# them.
source "$DOTFILES_DIR/lib/install-k8s-tools.sh"
if [ -f "$HOME/.local/bin/kubectl" ]; then
  echo "==> Updating kubectl (official binary)"
  download_kubectl || echo "    kubectl update failed, continuing"
fi
if [ -f "$HOME/.local/bin/k9s" ]; then
  echo "==> Updating k9s (upstream GitHub release)"
  download_k9s || echo "    k9s update failed, continuing"
fi
if [ -f "$HOME/.local/bin/kubelogin" ]; then
  echo "==> Updating kubelogin (upstream GitHub release)"
  download_kubelogin || echo "    kubelogin update failed, continuing"
fi

# Not an upgrade (Obsidian updates itself) — just picks up an Obsidian
# install that happened after install.sh last ran.
echo "==> Linking Obsidian CLI (only if Obsidian is installed)"
"$DOTFILES_DIR/lib/install-obsidian-cli.sh" || echo "    Obsidian CLI link failed, continuing"

echo "==> Done. Start a new terminal, or run: exec \$SHELL -l"
