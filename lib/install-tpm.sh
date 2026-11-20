#!/usr/bin/env bash
# tpm's install_plugins script reads its plugin list from a *running* tmux
# server that has already sourced ~/.tmux.conf (that's what sets
# TMUX_PLUGIN_MANAGER_PATH and the @plugin list) — so this spins up a
# detached session first, runs the installer against it, then tears it down.
set -euo pipefail

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ ! -d "$TPM_DIR" ]; then
  echo "==> Installing tmux plugin manager (TPM)"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

started_session=0
if ! tmux has-session -t dotfiles_tpm_install 2>/dev/null; then
  tmux new-session -d -s dotfiles_tpm_install
  started_session=1
fi

"$TPM_DIR/bin/install_plugins" || true

if [ "$started_session" = "1" ]; then
  tmux kill-session -t dotfiles_tpm_install 2>/dev/null || true
fi
