#!/usr/bin/env bash
# Full integration test: builds a containerized dev box per distro, runs
# install.sh as a non-root sudo user (mirroring a real machine), then runs
# test/checks.sh inside it. See CLAUDE.md for when this must be run.
#
# Usage:
#   test/run.sh                 # all supported distros
#   test/run.sh ubuntu arch     # just these
#
# Requires podman or docker (auto-detected; override with CONTAINER_ENGINE).
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TEST_DIR/.." && pwd)"

ENGINE="${CONTAINER_ENGINE:-}"
if [ -z "$ENGINE" ]; then
  if command -v podman >/dev/null 2>&1; then
    ENGINE=podman
  elif command -v docker >/dev/null 2>&1; then
    ENGINE=docker
  else
    echo "No container engine found (looked for podman, docker). Install one, or set CONTAINER_ENGINE." >&2
    exit 1
  fi
fi

distros=("$@")
if [ ${#distros[@]} -eq 0 ]; then
  distros=(ubuntu arch almalinux)
fi

# Per-distro extra flags, as plain space-separated strings (word-split on
# purpose below) rather than arrays: bash 3.2 — macOS's shipped /bin/bash,
# stuck there by GPLv2 licensing — errors on `"${arr[@]}"` for an empty
# array under `set -u` (fixed upstream in bash 4.4), and this script has to
# run correctly under 3.2 too.
#
# arch: Arch Linux proper only ships x86_64 — there's no arm64 track
#   (that's the separate Arch Linux ARM project) — so on an Apple
#   Silicon/arm64 host this needs emulation. (test/Dockerfile.arch
#   separately works around pacman's sandboxing not surviving that
#   emulation — see the comment there.)
platform_for() {
  case "$1" in
    arch) echo "linux/amd64" ;;
    *) echo "" ;;
  esac
}
flags_for() {
  p="$(platform_for "$1")"
  if [ -n "$p" ]; then echo "--platform $p"; else echo ""; fi
}
build_flags_for() { flags_for "$1"; }
run_flags_for() { flags_for "$1"; }

# Each step runs in its own freshly-sourced login shell: install.sh/
# uninstall.sh only change PATH or rc-file contents within their own
# process or on disk, the same way a real terminal wouldn't pick up a
# change until you opened a new one. The full sequence covers this repo's
# whole lifecycle, not just a first install: fresh install -> verify ->
# install again (must still succeed, not just "fail less loudly" —
# idempotency) -> verify again -> uninstall -> verify it's actually clean.
overall=0
for distro in "${distros[@]}"; do
  dockerfile="$TEST_DIR/Dockerfile.$distro"
  if [ ! -f "$dockerfile" ]; then
    echo "==> [$distro] SKIP: no $dockerfile" >&2
    overall=1
    continue
  fi

  build_flags="$(build_flags_for "$distro")"
  run_flags="$(run_flags_for "$distro")"

  image="dotfiles-test-$distro"
  echo "==> [$distro] building test image${build_flags:+ ($build_flags)}"
  build_ok=0
  "$ENGINE" build $build_flags -t "$image" -f "$dockerfile" "$REPO_DIR" && build_ok=1 || build_ok=0
  if [ "$build_ok" != "1" ]; then
    echo "==> [$distro] SKIP: image build failed (likely no image available for this host's architecture)" >&2
    overall=1
    continue
  fi

  echo "==> [$distro] running: install -> check -> reinstall -> check -> uninstall -> check"
  run_result=0
  "$ENGINE" run $run_flags --rm "$image" bash -c '
      set -e
      bash -lc "cd ~/.dotfiles && ./install.sh"                    && echo "--- first install OK ---" &&
      bash -lc "cd ~/.dotfiles && bash test/checks.sh"              && echo "--- post-install checks OK ---" &&
      bash -lc "cd ~/.dotfiles && ./install.sh"                     && echo "--- second install (idempotency) OK ---" &&
      bash -lc "cd ~/.dotfiles && bash test/checks.sh"              && echo "--- post-reinstall checks OK ---" &&
      bash -lc "cd ~/.dotfiles && ./uninstall.sh"                   && echo "--- uninstall OK ---" &&
      bash -lc "cd ~/.dotfiles && bash test/checks-uninstall.sh"    && echo "--- post-uninstall checks OK ---"
    ' && run_result=1 || run_result=0
  if [ "$run_result" = "1" ]; then
    echo "==> [$distro] PASS"
  else
    echo "==> [$distro] FAIL"
    overall=1
  fi
  echo
done

exit $overall
