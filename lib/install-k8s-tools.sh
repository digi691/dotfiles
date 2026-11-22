#!/usr/bin/env bash
# Installs Kubernetes CLI tooling: kubectl (official binary from dl.k8s.io),
# k9s (upstream GitHub release), and int128/kubelogin — a generic OIDC
# credential plugin for kubectl, not to be confused with the unrelated,
# Azure-specific Azure/kubelogin which also happens to be called
# "kubelogin" (deliberately not what this installs). All architecture-
# aware, no package manager, no sudo, same local-first pattern as
# Starship/fonts. Falls back to brew (a tap, for kubelogin specifically —
# it isn't in homebrew-core) then the system package manager if local
# installers are disabled or the download fails.
#
# The download_* functions are also sourced directly by update.sh (to
# force a fresh download rather than skip an already-present binary) —
# guarded below so sourcing this file doesn't also trigger a fresh install.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "$DOTFILES_DIR/lib/pkg.sh"

dotfiles_k8s_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *) return 1 ;;
  esac
}

# Unconditionally (re)downloads the official kubectl binary into
# ~/.local/bin. Returns non-zero (without aborting, since this file is
# sourced under set -e contexts too) if this OS/arch isn't supported or
# the download fails.
download_kubectl() {
  os=""
  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux) os="linux" ;;
  esac
  arch="$(dotfiles_k8s_arch || true)"
  [ -n "$os" ] && [ -n "$arch" ] || return 1

  mkdir -p "$HOME/.local/bin"
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" || return 1
  curl -fsSL -o "$HOME/.local/bin/kubectl" \
    "https://dl.k8s.io/release/${version}/bin/${os}/${arch}/kubectl" || return 1
  chmod +x "$HOME/.local/bin/kubectl"
}

# Unconditionally (re)downloads the latest k9s GitHub release into
# ~/.local/bin. Same non-abort-on-failure contract as download_kubectl.
download_k9s() {
  rel_os=""
  case "$(uname -s)" in
    Darwin) rel_os="Darwin" ;;
    Linux) rel_os="Linux" ;;
  esac
  arch="$(dotfiles_k8s_arch || true)"
  [ -n "$rel_os" ] && [ -n "$arch" ] || return 1

  mkdir -p "$HOME/.local/bin"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  url="https://github.com/derailed/k9s/releases/latest/download/k9s_${rel_os}_${arch}.tar.gz"
  curl -fsSL -o "$tmp/k9s.tar.gz" "$url" || return 1
  tar -xzf "$tmp/k9s.tar.gz" -C "$tmp" k9s || return 1
  mv "$tmp/k9s" "$HOME/.local/bin/k9s"
  chmod +x "$HOME/.local/bin/k9s"
}

# Unconditionally (re)downloads the latest int128/kubelogin GitHub
# release into ~/.local/bin. Same non-abort-on-failure contract as the
# other download_* functions.
download_kubelogin() {
  os=""
  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux) os="linux" ;;
  esac
  arch="$(dotfiles_k8s_arch || true)"
  [ -n "$os" ] && [ -n "$arch" ] || return 1

  mkdir -p "$HOME/.local/bin"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  url="https://github.com/int128/kubelogin/releases/latest/download/kubelogin_${os}_${arch}.zip"
  curl -fsSL -o "$tmp/kubelogin.zip" "$url" || return 1
  unzip -oq "$tmp/kubelogin.zip" -d "$tmp" kubelogin || return 1
  mv "$tmp/kubelogin" "$HOME/.local/bin/kubelogin"
  chmod +x "$HOME/.local/bin/kubelogin"
}

install_kubectl() {
  dotfiles_has kubectl && return 0
  if [ -z "${DOTFILES_NO_LOCAL_INSTALLERS:-}" ]; then
    echo "==> Installing kubectl (official binary, ~/.local/bin)"
    if download_kubectl; then
      return 0
    fi
    echo "==> Official kubectl download failed, falling back to brew/system package manager" >&2
  fi
  dotfiles_install kubectl
}

install_k9s() {
  dotfiles_has k9s && return 0
  if [ -z "${DOTFILES_NO_LOCAL_INSTALLERS:-}" ]; then
    echo "==> Installing k9s (upstream GitHub release, ~/.local/bin)"
    if download_k9s; then
      return 0
    fi
    echo "==> k9s GitHub release download failed, falling back to brew/system package manager" >&2
  fi
  dotfiles_install k9s
}

# kubelogin isn't in homebrew-core, so this doesn't reuse dotfiles_install
# (which only does a bare `brew install <formula>`) — it needs the
# tap-qualified name. No system-package tier either: it isn't in
# apt/pacman/dnf's official repos, so there's nothing useful to fall back
# to there.
install_kubelogin() {
  dotfiles_has kubelogin && return 0
  if [ -z "${DOTFILES_NO_LOCAL_INSTALLERS:-}" ]; then
    echo "==> Installing kubelogin (int128/kubelogin, upstream GitHub release, ~/.local/bin)"
    if download_kubelogin; then
      return 0
    fi
    echo "==> kubelogin GitHub release download failed, falling back to brew" >&2
  fi

  if [ -z "${DOTFILES_NO_BREW:-}" ] && dotfiles_ensure_brew; then
    brew install int128/kubelogin/kubelogin && return 0
  fi

  echo "dotfiles: could not install kubelogin (no local download, no brew available)" >&2
  echo "          install manually: https://github.com/int128/kubelogin#getting-started" >&2
  return 1
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  install_kubectl
  install_k9s
  install_kubelogin
fi
