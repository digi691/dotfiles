#!/usr/bin/env bash
# Reverses install.sh's rc-file wiring. Deliberately conservative: it only
# removes the guarded block this repo added to each rc file. Installed
# tools (Homebrew, oh-my-zsh, fonts, etc.) and the symlinked configs are
# left in place — delete those yourself if you want them gone too.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEGIN="# >>> dotfiles >>>"
END="# <<< dotfiles <<<"

strip_block() {
  file="$1"
  [ -f "$file" ] || return 0
  if ! grep -qF "$BEGIN" "$file" 2>/dev/null; then
    return 0
  fi
  awk -v b="$BEGIN" -v e="$END" '
    $0==b {skip=1; next}
    $0==e {skip=0; next}
    skip {next}
    {print}
  ' "$file" > "$file.dotfiles.tmp"
  mv "$file.dotfiles.tmp" "$file"
  echo "==> Removed dotfiles block from $file"
}

for f in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zprofile" "$HOME/.zshrc"; do
  strip_block "$f"
done

cat <<EOF

Rc files are clean again. Still in place, if you want to remove them by hand:
  rm -f ~/.vimrc ~/.tmux.conf ~/.config/starship.toml
  rm -rf ~/.oh-my-zsh ~/.vim/plugged ~/.tmux/plugins
  rm -rf $DOTFILES_DIR
EOF
