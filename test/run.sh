#!/usr/bin/env bash
# Full integration test: builds a containerized dev box per distro, runs
# this repo's full install/update/uninstall lifecycle as a non-root sudo
# user (mirroring a real machine), plus one check that install.sh
# auto-symlinks ~/.dotfiles correctly when the repo lives elsewhere. See
# CLAUDE.md for when this must be run.
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

# Distros run in parallel, one background job each — they're fully
# independent (separate images, separate containers), so the wall-clock
# cost is the slowest distro rather than the sum of all of them. Each job
# writes its full output to its own log under $LOG_DIR and streams it live
# with a [name] prefix, so interleaved output stays attributable. Results
# go to $LOG_DIR/<name>.status (PASS/FAIL/SKIP) rather than exit codes, so
# the summary at the end doesn't depend on job-control behavior that
# differs between bash versions.
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
# Every container this run starts carries this label, so an interrupted
# run can find and remove its own containers without touching anyone
# else's. (`--rm` alone doesn't cover that: killing the engine client
# doesn't stop the container it started.)
RUN_LABEL="dotfiles-test-run=$$"
JOB_PIDS=""
# The run's real stdout, for relocated-source: it's started from inside the
# ubuntu job, and would otherwise get prefixed a second time by that job's
# pipe and land in ubuntu.log too.
exec 3>&1

prefix() {
  while IFS= read -r line || [ -n "$line" ]; do
    printf '[%s] %s\n' "$1" "$line"
  done
}

kill_tree() {
  for child in $(pgrep -P "$1" 2>/dev/null); do
    kill_tree "$child"
  done
  kill "$1" 2>/dev/null || true
}

cleanup() {
  trap - INT TERM
  echo "==> Interrupted: stopping test jobs and their containers" >&2
  for pid in $JOB_PIDS; do
    kill_tree "$pid"
  done
  ids="$("$ENGINE" ps -aq --filter "label=$RUN_LABEL" 2>/dev/null || true)"
  if [ -n "$ids" ]; then
    "$ENGINE" rm -f $ids >/dev/null 2>&1 || true
  fi
  echo "==> Logs kept in $LOG_DIR" >&2
  exit 130
}
trap cleanup INT TERM

# Each step runs in its own freshly-sourced login shell: install.sh/
# uninstall.sh only change PATH or rc-file contents within their own
# process or on disk, the same way a real terminal wouldn't pick up a
# change until you opened a new one. The full sequence covers this repo's
# whole lifecycle, not just a first install: fresh install -> verify ->
# install again (must still succeed, not just "fail less loudly" —
# idempotency) -> verify again -> update.sh -> verify nothing broke ->
# uninstall -> verify it's actually clean. update.sh reuses checks.sh
# rather than a dedicated checks-update.sh: a successful update shouldn't
# change any of those invariants, so the same assertions double as the
# "did update.sh break anything" check.
run_lifecycle() {
  distro="$1"
  image="dotfiles-test-$distro"
  run_flags="$(run_flags_for "$distro")"
  echo "==> [$distro] running: install -> check -> reinstall -> check -> update -> check -> uninstall -> check"
  if "$ENGINE" run $run_flags --rm --label "$RUN_LABEL" "$image" bash -c '
      set -e
      bash -lc "cd ~/.dotfiles && ./install.sh"                    && echo "--- first install OK ---" &&
      bash -lc "cd ~/.dotfiles && bash test/checks.sh"              && echo "--- post-install checks OK ---" &&
      bash -lc "cd ~/.dotfiles && ./install.sh"                     && echo "--- second install (idempotency) OK ---" &&
      bash -lc "cd ~/.dotfiles && bash test/checks.sh"              && echo "--- post-reinstall checks OK ---" &&
      bash -lc "cd ~/.dotfiles && ./update.sh"                      && echo "--- update OK ---" &&
      bash -lc "cd ~/.dotfiles && bash test/checks.sh"              && echo "--- post-update checks OK ---" &&
      bash -lc "cd ~/.dotfiles && ./uninstall.sh"                   && echo "--- uninstall OK ---" &&
      bash -lc "cd ~/.dotfiles && bash test/checks-uninstall.sh"    && echo "--- post-uninstall checks OK ---"
    '; then
    echo "==> [$distro] PASS"
    echo PASS > "$LOG_DIR/$distro.status"
  else
    echo "==> [$distro] FAIL"
    echo FAIL > "$LOG_DIR/$distro.status"
  fi
}

# Every container above places the repo at exactly ~/.dotfiles via its
# Dockerfile's COPY, so none of them actually exercise install.sh's
# "repo lives somewhere else, auto-symlink ~/.dotfiles to it" path — the
# exact scenario that bit a real run of this once already. Covered here
# as one extra check, reusing the ubuntu image rather than adding a whole
# new distro dimension to every run.
run_relocated() {
  echo "==> [relocated-source] verifying install.sh auto-symlinks ~/.dotfiles when the repo lives elsewhere"
  if "$ENGINE" run --rm --label "$RUN_LABEL" dotfiles-test-ubuntu bash -c '
      set -e
      mv /home/tester/.dotfiles /home/tester/dotfiles-src
      bash -lc "cd /home/tester/dotfiles-src && ./install.sh" &&
      [ -L /home/tester/.dotfiles ] &&
      [ "$(readlink /home/tester/.dotfiles)" = "/home/tester/dotfiles-src" ] &&
      echo "--- symlink points at relocated source OK ---" &&
      bash -lc "cd /home/tester/.dotfiles && bash test/checks.sh"
    '; then
    echo "==> [relocated-source] PASS"
    echo PASS > "$LOG_DIR/relocated-source.status"
  else
    echo "==> [relocated-source] FAIL"
    echo FAIL > "$LOG_DIR/relocated-source.status"
  fi
}

# One job per distro: build its image, then run its lifecycle. The ubuntu
# job also kicks off relocated-source as soon as its image exists, running
# alongside ubuntu's own lifecycle instead of waiting for it.
distro_job() {
  distro="$1"
  dockerfile="$TEST_DIR/Dockerfile.$distro"
  if [ ! -f "$dockerfile" ]; then
    echo "==> [$distro] SKIP: no $dockerfile"
    echo SKIP > "$LOG_DIR/$distro.status"
    return 0
  fi

  build_flags="$(build_flags_for "$distro")"
  echo "==> [$distro] building test image${build_flags:+ ($build_flags)}"
  if ! "$ENGINE" build $build_flags -t "dotfiles-test-$distro" -f "$dockerfile" "$REPO_DIR"; then
    echo "==> [$distro] SKIP: image build failed (likely no image available for this host's architecture)"
    echo SKIP > "$LOG_DIR/$distro.status"
    return 0
  fi

  if [ "$distro" = "ubuntu" ]; then
    relocated_job &
    run_lifecycle "$distro"
    wait
  else
    run_lifecycle "$distro"
  fi
}

relocated_job() {
  run_relocated 2>&1 | tee "$LOG_DIR/relocated-source.log" | prefix relocated-source >&3
}

start_job() {
  name="$1"; shift
  ( "$@" 2>&1 | tee "$LOG_DIR/$name.log" | prefix "$name" ) &
  JOB_PIDS="$JOB_PIDS $!"
}

echo "==> Running in parallel: ${distros[*]} (full logs: $LOG_DIR)"
ubuntu_requested=0
for distro in "${distros[@]}"; do
  [ "$distro" = "ubuntu" ] && ubuntu_requested=1
  start_job "$distro" distro_job "$distro"
done

# Not running ubuntu this time: fall back to an ubuntu image left over from
# an earlier run, if there is one, same as before this ran in parallel.
results="${distros[*]}"
if [ "$ubuntu_requested" = "1" ]; then
  results="$results relocated-source"
elif "$ENGINE" image inspect dotfiles-test-ubuntu >/dev/null 2>&1; then
  results="$results relocated-source"
  ( relocated_job ) &
  JOB_PIDS="$JOB_PIDS $!"
else
  echo "==> [relocated-source] SKIP: no ubuntu image available (run with ubuntu to build one)" >&2
fi

for pid in $JOB_PIDS; do
  wait "$pid" || true
done

overall=0
echo
echo "===== summary ====="
for name in $results; do
  # No status file means the job died before recording one (e.g. the
  # ubuntu build failed, so relocated-source never started).
  status="$(cat "$LOG_DIR/$name.status" 2>/dev/null || echo SKIP)"
  printf '  %-18s %s\n' "$name" "$status"
  case "$status" in
    PASS) ;;
    FAIL) overall=1; echo "                     log: $LOG_DIR/$name.log" ;;
    *) overall=1 ;;
  esac
done
echo "Full logs: $LOG_DIR"

exit $overall
