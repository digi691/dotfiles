# POSIX sh. Sourced from ~/.zprofile and ~/.bash_profile — login-shell-only
# setup (PATH, etc.) shared across both shells so GUI-launched apps and
# login sessions see the same environment regardless of which shell they use.
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

[ -f "$DOTFILES_DIR/shell/common/os-detect.sh" ] && . "$DOTFILES_DIR/shell/common/os-detect.sh"
[ -f "$DOTFILES_DIR/shell/common/path.sh" ] && . "$DOTFILES_DIR/shell/common/path.sh"
