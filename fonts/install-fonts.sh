#!/usr/bin/env bash
# Downloads a Nerd Font patched variant straight from upstream releases and
# installs it into a user-local font directory — no package manager, no
# sudo, works the same on macOS and any Linux distro.
#
# Usage: fonts/install-fonts.sh [FontName]   (default: Hack)
# Browse available names at https://github.com/ryanoasis/nerd-fonts/releases
set -euo pipefail

FONT_NAME="${1:-Hack}"
VERSION="${NERD_FONTS_VERSION:-v3.3.0}"
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${VERSION}/${FONT_NAME}.zip"

case "$(uname -s)" in
  Darwin) DEST="$HOME/Library/Fonts" ;;
  *)      DEST="$HOME/.local/share/fonts" ;;
esac
mkdir -p "$DEST"

if find "$DEST" -iname "*${FONT_NAME}*Nerd Font*" 2>/dev/null | grep -q .; then
  echo "==> ${FONT_NAME} Nerd Font already installed in $DEST"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> Downloading ${FONT_NAME} Nerd Font ${VERSION}"
curl -fsSL "$URL" -o "$tmp/font.zip"
unzip -oq "$tmp/font.zip" -d "$tmp/extracted"

find "$tmp/extracted" \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp {} "$DEST/" \;

if [ "$(uname -s)" = "Linux" ] && command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$DEST" >/dev/null
fi

echo "==> Installed ${FONT_NAME} Nerd Font to $DEST"
echo "    Point your terminal's font at: ${FONT_NAME} Nerd Font Mono"
