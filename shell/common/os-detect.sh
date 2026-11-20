# POSIX sh. Sourced by bash, zsh, and login profiles alike — no bashisms/zshisms.
case "$(uname -s)" in
  Darwin)
    DOTFILES_OS="macos"
    DOTFILES_DISTRO="macos"
    ;;
  Linux)
    DOTFILES_OS="linux"
    if [ -f /etc/os-release ]; then
      DOTFILES_DISTRO="$(. /etc/os-release && echo "$ID")"
    else
      DOTFILES_DISTRO="unknown"
    fi
    ;;
  *)
    DOTFILES_OS="unknown"
    DOTFILES_DISTRO="unknown"
    ;;
esac
export DOTFILES_OS DOTFILES_DISTRO
