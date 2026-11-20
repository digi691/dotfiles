#!/usr/bin/env bash
# Package install abstraction: local method first, Homebrew/Linuxbrew second,
# the OS's own package manager last. Sourced by install.sh and the lib/install-*.sh
# helpers — never run directly.
#
# Overrides (export before running install.sh):
#   DOTFILES_NO_BREW=1              skip Homebrew entirely, go straight to system packages
#   DOTFILES_NO_LOCAL_INSTALLERS=1  skip official curl-installer scripts (starship, etc.)

dotfiles_has() { command -v "$1" >/dev/null 2>&1; }

dotfiles_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if [ -f /etc/os-release ]; then
        ID="$(. /etc/os-release && echo "$ID")"
        case "$ID" in
          ubuntu|debian) echo "debian" ;;
          arch) echo "arch" ;;
          almalinux|rhel|rocky|centos|fedora) echo "redhat" ;;
          *) echo "linux-other" ;;
        esac
      else
        echo "linux-other"
      fi
      ;;
    *) echo "unknown" ;;
  esac
}

dotfiles_ensure_brew() {
  dotfiles_has brew && return 0
  [ -n "$DOTFILES_NO_BREW" ] && return 1

  echo "==> Installing Homebrew (user-writable prefix, no system packages touched)"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ -d /opt/homebrew/bin ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -d "$HOME/.linuxbrew/bin" ]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
  fi

  dotfiles_has brew
}

# A handful of packages have different names on RHEL-family distros
# (AlmaLinux/RHEL/Rocky/Fedora ship vim-minimal by default; the full vim
# with +clipboard etc. is "vim-enhanced", not "vim").
dotfiles_redhat_name() {
  case "$1" in
    vim) echo "vim-enhanced" ;;
    *) echo "$1" ;;
  esac
}

dotfiles_sys_install() {
  pkg="$1"
  case "$(dotfiles_os)" in
    debian) sudo apt-get update -qq && sudo apt-get install -y "$pkg" ;;
    arch)   sudo pacman -Sy --noconfirm "$pkg" ;;
    redhat) sudo dnf install -y "$(dotfiles_redhat_name "$pkg")" ;;
    macos)  echo "dotfiles: no non-brew fallback defined for macOS ($pkg)" >&2; return 1 ;;
    *)      echo "dotfiles: no system package mapping for $pkg on this OS" >&2; return 1 ;;
  esac
}

# Generic path for simple CLI tools (zsh, tmux, vim, git, curl): try brew
# first, fall back to the native package manager.
dotfiles_install() {
  pkg="$1"
  dotfiles_has "$pkg" && return 0

  if [ -z "$DOTFILES_NO_BREW" ] && dotfiles_ensure_brew; then
    if brew install "$pkg"; then
      return 0
    fi
  fi

  echo "==> Falling back to the system package manager for $pkg"
  dotfiles_sys_install "$pkg"
}
