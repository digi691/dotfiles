#!/usr/bin/env bash
set -euo pipefail

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ ! -d "$TPM_DIR" ]; then
  echo "==> Installing tmux plugin manager (TPM)"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

"$TPM_DIR/bin/install_plugins" || true
