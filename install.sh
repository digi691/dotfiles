#!/usr/bin/env bash
# Sets up this repo on a new machine: installs tools (local-first, with a
# system-package fallback), then wires ~/.bashrc, ~/.bash_profile,
# ~/.zprofile and ~/.zshrc to bootstrap from this repo. See README.md.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
source "$DOTFILES_DIR/lib/pkg.sh"

if [ "$DOTFILES_DIR" != "$HOME/.dotfiles" ]; then
  echo "==> Warning: this repo is at $DOTFILES_DIR, but the shell rc files will" >&2
  echo "    be wired to look for it at \$HOME/.dotfiles (so the setup is portable" >&2
  echo "    across machines/usernames). Clone to ~/.dotfiles, or symlink it there." >&2
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
