#!/usr/bin/env bash
# Starship ships its own official local installer (no package manager, no
# sudo, drops a single binary in ~/.local/bin) — that's the truest "local"
# install path, so it's tried before Homebrew.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/lib/pkg.sh"

if dotfiles_has starship; then
  exit 0
fi

if [ -z "${DOTFILES_NO_LOCAL_INSTALLERS:-}" ]; then
  echo "==> Installing starship via its official local installer (~/.local/bin)"
  mkdir -p "$HOME/.local/bin"
  if curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$HOME/.local/bin" -y; then
    exit 0
  fi
  echo "==> Local starship installer failed, falling back to brew/system package manager" >&2
fi

dotfiles_install starship
