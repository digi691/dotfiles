#!/usr/bin/env bash
# Idempotently writes/updates a single guarded block in each shell rc file.
# Everything else in those files is left completely alone, and uninstall.sh
# reverses this by stripping the same markers.
set -euo pipefail

BEGIN="# >>> dotfiles >>>"
END="# <<< dotfiles <<<"

strip_block() {
  file="$1"
  [ -f "$file" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '
    $0==b {skip=1; next}
    $0==e {skip=0; next}
    skip {next}
    {print}
  ' "$file" > "$file.dotfiles.tmp"
  mv "$file.dotfiles.tmp" "$file"
}

append_block() {
  file="$1"; shift
  touch "$file"
  {
    echo "$BEGIN"
    printf '%s\n' "$@"
    echo "$END"
  } >> "$file"
}

inject() {
  file="$1"; shift
  strip_block "$file"
  append_block "$file" "$@"
  echo "==> Wired $file"
}

inject "$HOME/.bashrc" \
  'export DOTFILES_DIR="$HOME/.dotfiles"' \
  '[ -f "$DOTFILES_DIR/shell/bootstrap.bash" ] && source "$DOTFILES_DIR/shell/bootstrap.bash"'

inject "$HOME/.bash_profile" \
  'export DOTFILES_DIR="$HOME/.dotfiles"' \
  '[ -f "$DOTFILES_DIR/shell/bootstrap.profile.sh" ] && . "$DOTFILES_DIR/shell/bootstrap.profile.sh"' \
  '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"'

inject "$HOME/.zprofile" \
  'export DOTFILES_DIR="$HOME/.dotfiles"' \
  '[ -f "$DOTFILES_DIR/shell/bootstrap.profile.sh" ] && . "$DOTFILES_DIR/shell/bootstrap.profile.sh"'

inject "$HOME/.zshrc" \
  'export DOTFILES_DIR="$HOME/.dotfiles"' \
  '[ -f "$DOTFILES_DIR/shell/bootstrap.zsh" ] && source "$DOTFILES_DIR/shell/bootstrap.zsh"'
