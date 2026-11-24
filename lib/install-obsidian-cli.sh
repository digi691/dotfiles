#!/usr/bin/env bash
# Puts Obsidian's official CLI on PATH as `obsidian` — but only if the
# Obsidian desktop app is already installed. This never installs Obsidian
# itself; it just wires up the CLI binary the app ships with.
#
# Why a symlink into ~/.local/bin rather than adding the app bundle's
# Contents/MacOS dir to PATH: that dir also holds the GUI executable
# `Obsidian`, and on macOS's case-insensitive filesystem `obsidian` would
# resolve to the GUI app, not the CLI (`obsidian-cli`). Obsidian's own
# "Register CLI" step does the equivalent, but into /usr/local/bin (needs
# admin), so this is the no-sudo version of the same thing.
#
# Linux needs nothing here: Obsidian's CLI registration there copies the
# binary straight to ~/.local/bin/obsidian, which shell/common/path.sh
# already puts on PATH.
#
# OBSIDIAN_APP overrides the app bundle location (used by test/checks.sh
# to exercise this against a fake bundle on Linux).
set -euo pipefail

if [ -n "${OBSIDIAN_APP:-}" ]; then
  set -- "$OBSIDIAN_APP"
elif [ "$(uname -s)" = "Darwin" ]; then
  set -- /Applications/Obsidian.app "$HOME/Applications/Obsidian.app"
else
  exit 0
fi

cli=""
for app in "$@"; do
  if [ -x "$app/Contents/MacOS/obsidian-cli" ]; then
    cli="$app/Contents/MacOS/obsidian-cli"
    break
  fi
done

if [ -z "$cli" ]; then
  echo "    Obsidian not installed (or too old to ship obsidian-cli, needs 1.12.7+), skipping"
  exit 0
fi

link="$HOME/.local/bin/obsidian"
# Don't clobber a real file someone put there; a symlink is ours to refresh
# (e.g. if the app moved between /Applications and ~/Applications).
if [ -e "$link" ] && [ ! -L "$link" ]; then
  echo "    $link already exists and isn't a symlink, leaving it alone"
  exit 0
fi

mkdir -p "$HOME/.local/bin"
ln -sfn "$cli" "$link"
echo "    Linked $link -> $cli"
