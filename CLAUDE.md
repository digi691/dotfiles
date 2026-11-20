# CLAUDE.md

Guidance for Claude Code (or any future contributor) working in this repo.
See README.md for what this project is and how a user installs it; this
file is about how to safely change it.

## Why this needs a real test harness

This repo's entire value is that `install.sh` behaves correctly on a
machine that has *nothing* on it yet — no Homebrew, no oh-my-zsh, no vim
plugins, rc files untouched. That's exactly the state a sandboxed/local
run can't easily exercise by inspection, and it's exactly where this repo
has already broken in practice: an unset-variable crash under `set -u`, and
two install-ordering bugs where oh-my-zsh's installer or vim-plug/TPM ran
before the config they depend on was in place. All three only showed up by
actually running `install.sh` on a clean box — reading the script did not
catch them. Treat that as the baseline risk for any change here, not an
edge case.

## The test harness

- **`test/lint.sh`** — fast, no containers. `bash -n`/`zsh -n` over every
  shell file in the repo. Catches syntax errors in seconds. Run this
  constantly while iterating.
- **`test/run.sh [distro ...]`** — the real test. Builds a container per
  distro (`test/Dockerfile.ubuntu`, `.arch`, `.almalinux`) as a non-root
  user with passwordless sudo (mirroring a real dev box — Homebrew's
  installer refuses to run as root), then runs this repo's full lifecycle
  inside it: `install.sh` → `test/checks.sh` → `install.sh` again
  (idempotency — a second run must still succeed, not just fail quietly)
  → `test/checks.sh` again → `uninstall.sh` → `test/checks-uninstall.sh`.
  Defaults to all three distros; pass names to run a subset, e.g.
  `test/run.sh ubuntu`. Auto-detects `podman` or `docker`; override with
  `CONTAINER_ENGINE`.
- **`test/checks.sh`** — post-install assertions (rc files stayed minimal,
  tools resolve on PATH, configs are symlinked not copied, every plugin
  manager's plugins actually landed, the bash→zsh handoff and its
  `DOTFILES_NO_EXEC_ZSH` override both behave correctly). Also re-run
  after the second `install.sh`, so it doubles as the idempotency check.
- **`test/checks-uninstall.sh`** — post-uninstall assertions: the rc-file
  blocks are actually gone and the bash→zsh handoff is gone with them, but
  everything `uninstall.sh` deliberately leaves alone (oh-my-zsh, the
  symlinked configs) is still there.

Both check scripts print PASS/FAIL per check inside the container and
exit non-zero if anything failed.

## Known environment quirks (container-harness-only, not install.sh bugs)

These showed up building the test images themselves, not from running
`install.sh`. If a *build* step fails (as opposed to the install/check
step), suspect one of these first rather than editing `install.sh`:

- **Arch on an arm64 host**: Arch Linux proper only publishes x86_64
  images (there's no arm64 track — that's the separate Arch Linux ARM
  project), so `test/run.sh` builds/runs the `arch` image under
  `--platform linux/amd64` emulation. It also needs
  `--security-opt seccomp=unconfined` on the build: pacman's own
  sandboxing (an "alpm" sandbox user + seccomp) doesn't work layered
  inside podman's confinement, especially under emulation — a known
  pacman-in-containers issue. Both flags live in `build_flags_for`/
  `run_flags_for` in `test/run.sh`.
- **AlmaLinux's `curl` package**: `test/Dockerfile.almalinux` deliberately
  does *not* list `curl` — the base image ships `curl-minimal`
  (providing `/usr/bin/curl`) and requesting the full `curl` package
  conflicts with it. `curl-minimal` is sufficient for everything
  `install.sh` needs (plain HTTPS GETs); don't "fix" this by adding
  `curl` back or passing `--allowerasing`.

## Rules for changes in this repo

1. **Any change to `install.sh`, `uninstall.sh`, `lib/`, `shell/`,
   `config/`, `vim/`, `tmux/`, `fonts/`, or `packages/` is not done until
   `test/lint.sh` passes and `test/run.sh` passes for every distro that
   change could plausibly affect.** If you're not sure which distros are
   affected, run all three. Don't report a shell/install change complete
   on the strength of reading the code or a syntax check alone.

2. **A new install step needs a new check, in the same change.** Adding a
   package, a zsh/vim/tmux plugin, a symlink, or a font means adding the
   matching assertion to `test/checks.sh` — otherwise `install.sh` can
   silently regress on that step forever. Follow the existing pattern
   (`check "description" command...`). If `uninstall.sh` should also
   affect it (or deliberately shouldn't), add the matching assertion to
   `test/checks-uninstall.sh` too.

3. **Adding support for a new distro** means adding
   `test/Dockerfile.<name>` (same shape as the existing three: a
   non-root user named `tester` with passwordless sudo, plus whatever
   minimal base packages Homebrew/curl/git need on that distro) and adding
   `<name>` to the default list in `test/run.sh`.

4. **Any optional override env var** (`DOTFILES_NO_BREW`,
   `DOTFILES_NO_LOCAL_INSTALLERS`, `DOTFILES_NO_EXEC_ZSH`, etc.) **must be
   referenced as `${VAR:-}`, never bare `$VAR`**, in any script that has
   `set -u` (every script under `lib/`, plus `install.sh`/`uninstall.sh`).
   A bare reference crashes the whole install the first time someone runs
   it without that variable set — this exact bug shipped once already.

5. **Ordering matters more than it looks like it should.** oh-my-zsh's
   installer only preserves an *existing* `~/.zshrc` — if nothing wires the
   dotfiles block into it first, it overwrites it with the stock omz
   template. vim-plug and TPM both read their plugin list out of the real
   `vimrc`/`tmux.conf` — if those aren't symlinked into place yet, there's
   nothing for either to install. If you reorder steps in `install.sh`,
   re-read the comments already there explaining these two dependencies,
   and re-run the full harness — don't assume independence between steps.

6. Keep `test/checks.sh` and `test/lint.sh` themselves covered by
   `test/lint.sh`'s own sweep (they're plain `.sh` files, so this is
   automatic) — don't exclude the test harness from the thing it enforces
   on everything else.
