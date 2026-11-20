#!/usr/bin/env bash
# Post-uninstall verification, run inside a test container (see
# test/run.sh) right after uninstall.sh. Confirms disconnection is actually
# clean: rc files lose the dotfiles block, but uninstall.sh's deliberately
# conservative about everything else (installed tools, symlinked configs
# stay) — see its own comments for why.
set -u

HOME_="$HOME"
pass=0
fail=0

check() {
  desc="$1"; shift
  if "$@" >/tmp/dotfiles-check.$$ 2>&1; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    sed 's/^/       /' /tmp/dotfiles-check.$$
    fail=$((fail + 1))
  fi
  rm -f /tmp/dotfiles-check.$$
}

rc_block_absent() {
  ! grep -qF '# >>> dotfiles >>>' "$1"
}

check_handoff_absent() {
  result=$(printf 'echo HANDOFF=$0\n' | bash -li 2>/dev/null)
  echo "$result" | grep -q "HANDOFF=bash"
}

check ".zshrc no longer carries the dotfiles block"        rc_block_absent "$HOME_/.zshrc"
check ".bashrc no longer carries the dotfiles block"       rc_block_absent "$HOME_/.bashrc"
check ".bash_profile no longer carries the dotfiles block" rc_block_absent "$HOME_/.bash_profile"
check ".zprofile no longer carries the dotfiles block"     rc_block_absent "$HOME_/.zprofile"

check "bash no longer hands off to zsh (disconnected)" check_handoff_absent

# uninstall.sh is deliberately conservative — it only touches rc files.
check "oh-my-zsh is untouched by uninstall"    [ -d "$HOME_/.oh-my-zsh" ]
check "~/.vimrc symlink is untouched"          [ -L "$HOME_/.vimrc" ]
check "~/.tmux.conf symlink is untouched"      [ -L "$HOME_/.tmux.conf" ]

echo
echo "===== $pass passed, $fail failed ====="
[ "$fail" -eq 0 ]
