#!/usr/bin/env bash
# Verification suite for install.sh, run inside a test container (see
# test/run.sh) as the non-root test user, after install.sh has completed.
# Add a check here whenever install.sh gains a new install step, symlink,
# or plugin — see CLAUDE.md.
set -u

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
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

rc_block_has() {
  grep -qF '# >>> dotfiles >>>' "$1" && grep -qF "$2" "$1"
}

same_target() {
  [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]
}

check_handoff() {
  mode="$1" # default | noexec
  if [ "$mode" = "noexec" ]; then
    result=$(printf 'echo HANDOFF=$0\n' | DOTFILES_NO_EXEC_ZSH=1 bash -li 2>/dev/null)
    expect="bash"
  else
    result=$(printf 'echo HANDOFF=$0\n' | bash -li 2>/dev/null)
    expect="zsh"
  fi
  echo "$result" | grep -q "HANDOFF=$expect"
}

# ---- core tools on PATH ----
check "zsh resolves on PATH"      command -v zsh
check "starship resolves on PATH" command -v starship
check "git resolves on PATH"      command -v git
check "tmux resolves on PATH"     command -v tmux
check "vim resolves on PATH"      command -v vim

# ---- rc files stay minimal, pointed at this repo ----
check ".zshrc carries the dotfiles block"        rc_block_has "$HOME/.zshrc" 'bootstrap.zsh'
check ".bashrc carries the dotfiles block"       rc_block_has "$HOME/.bashrc" 'bootstrap.bash'
check ".bash_profile carries the dotfiles block" rc_block_has "$HOME/.bash_profile" 'bootstrap.profile.sh'
check ".zprofile carries the dotfiles block"     rc_block_has "$HOME/.zprofile" 'bootstrap.profile.sh'

# ---- configs linked from the repo, not copied ----
check "~/.vimrc symlinked to repo"                same_target "$HOME/.vimrc" "$DOTFILES_DIR/vim/vimrc"
check "~/.tmux.conf symlinked to repo"            same_target "$HOME/.tmux.conf" "$DOTFILES_DIR/tmux/tmux.conf"
check "~/.config/starship.toml symlinked to repo" same_target "$HOME/.config/starship.toml" "$DOTFILES_DIR/config/starship.toml"

# ---- oh-my-zsh + plugins ----
check "oh-my-zsh installed"               [ -d "$HOME/.oh-my-zsh" ]
check "zsh-autosuggestions installed"     [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]
check "zsh-syntax-highlighting installed" [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]
check "zsh-completions installed"         [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" ]

# ---- vim-plug + plugins ----
check "vim-plug installed" [ -f "$HOME/.vim/autoload/plug.vim" ]
for p in vim-sensible vim-surround vim-commentary vim-gitgutter; do
  check "vim plugin $p installed" [ -d "$HOME/.vim/plugged/$p" ]
done

# ---- tmux + TPM plugins ----
check "tpm installed"            [ -d "$HOME/.tmux/plugins/tpm" ]
check "tmux-sensible installed"  [ -d "$HOME/.tmux/plugins/tmux-sensible" ]
check "tmux-resurrect installed" [ -d "$HOME/.tmux/plugins/tmux-resurrect" ]

# ---- fonts ----
check "a Nerd Font got installed" bash -c \
  'find "$HOME/.local/share/fonts" "$HOME/Library/Fonts" -iname "*Nerd*Font*" 2>/dev/null | grep -q .'

# ---- the shell-handoff behavior this whole repo is built around ----
check "zsh loads cleanly via its bootstrap"           bash -c 'zsh -i -c "exit 0"'
check "bash hands off to zsh interactively"           check_handoff default
check "DOTFILES_NO_EXEC_ZSH=1 keeps bash interactive" check_handoff noexec

echo
echo "===== $pass passed, $fail failed ====="
[ "$fail" -eq 0 ]
