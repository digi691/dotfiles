#!/usr/bin/env bash
# Sets up this repo on a new machine: installs tools (local-first, with a
# system-package fallback), then wires ~/.bashrc, ~/.bash_profile,
# ~/.zprofile and ~/.zshrc to bootstrap from this repo. See README.md.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
source "$DOTFILES_DIR/lib/pkg.sh"

# Rc files always reference $HOME/.dotfiles (lib/inject-rc.sh), not
# whatever path this script actually happens to run from — that keeps the
# rc-file wiring identical across machines/usernames regardless of where
# each one's clone lives. So if this repo isn't already there, make it so:
# symlink $HOME/.dotfiles to wherever it actually is. Running install.sh
# *through* an existing correct symlink resolves DOTFILES_DIR to
# $HOME/.dotfiles already (plain `pwd` preserves the path you cd'ed via,
# not the symlink's target), so this block is a no-op on every subsequent
# run — it only ever acts the first time, or if the repo moves.
CANONICAL_DOTFILES="$HOME/.dotfiles"
if [ "$DOTFILES_DIR" != "$CANONICAL_DOTFILES" ]; then
  if [ -L "$CANONICAL_DOTFILES" ]; then
    existing_target="$(readlink "$CANONICAL_DOTFILES")"
    if [ "$existing_target" != "$DOTFILES_DIR" ]; then
      echo "==> ERROR: $CANONICAL_DOTFILES is a symlink to $existing_target, not $DOTFILES_DIR." >&2
      echo "    Rc files are wired to \$HOME/.dotfiles for portability across machines/usernames." >&2
      echo "    Fix or remove that symlink (it may point at a different, intentional clone), then re-run." >&2
      exit 1
    fi
  elif [ -e "$CANONICAL_DOTFILES" ]; then
    echo "==> ERROR: $CANONICAL_DOTFILES already exists and isn't a symlink." >&2
    echo "    Rc files are wired to \$HOME/.dotfiles for portability across machines/usernames." >&2
    echo "    Move it aside (it may be unrelated, pre-existing data), then re-run." >&2
    exit 1
  else
    echo "==> This repo is at $DOTFILES_DIR, not \$HOME/.dotfiles — symlinking $CANONICAL_DOTFILES -> $DOTFILES_DIR"
    ln -s "$DOTFILES_DIR" "$CANONICAL_DOTFILES"
  fi
fi

echo "==> Detected OS: $(dotfiles_os)"

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/fonts" "$HOME/.config"

echo "==> Installing core tools (zsh, tmux, vim, git, curl)"
for pkg in zsh tmux vim git curl; do
  dotfiles_install "$pkg"
done

# Wire the rc files before oh-my-zsh runs: its installer only leaves an
# existing ~/.zshrc alone (KEEP_ZSHRC=yes) if one already exists — otherwise
# it drops in its own full template, defeating the "rc files stay empty"
# design. Pre-seeding it with just our guarded block first means that's the
# "existing config" omz finds and preserves.
echo "==> Wiring shell entrypoints (.bashrc, .bash_profile, .zprofile, .zshrc)"
"$DOTFILES_DIR/lib/inject-rc.sh"

echo "==> Installing Starship prompt"
"$DOTFILES_DIR/lib/install-starship.sh"

echo "==> Installing oh-my-zsh + plugins"
"$DOTFILES_DIR/lib/install-omz.sh"

# Configs must be linked before vim-plug/TPM run below — both drive their
# install through the real vimrc/tmux.conf (that's what defines the plugin
# list), not a bare editor/multiplexer.
echo "==> Linking configs"
mkdir -p "$HOME/.config"
ln -sf "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
ln -sf "$DOTFILES_DIR/vim/vimrc" "$HOME/.vimrc"
ln -sf "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

echo "==> Installing vim-plug + vim plugins"
"$DOTFILES_DIR/lib/install-vim-plug.sh"

echo "==> Installing tmux plugin manager (TPM) + plugins"
"$DOTFILES_DIR/lib/install-tpm.sh"

echo "==> Installing fonts (default: Hack Nerd Font)"
"$DOTFILES_DIR/fonts/install-fonts.sh" "${DOTFILES_FONT:-Hack}"

echo "==> Done. Start a new terminal, or run: exec \$SHELL -l"
