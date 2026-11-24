# dotfiles

Cross-platform terminal setup (zsh + oh-my-zsh, Starship, vim, tmux, fonts)
for bouncing between a macOS daily driver and Linux dev boxes (Ubuntu, Arch,
AlmaLinux) over SSH, with bash as a common starting point.

## Philosophy

- **Rc files stay almost empty.** `~/.bashrc`, `~/.bash_profile`,
  `~/.zprofile`, and `~/.zshrc` each get exactly one guarded block that
  points at this repo and sources a bootstrap file — nothing else lives in
  them. That means disconnecting or starting over is just deleting four
  small blocks (`uninstall.sh` does it) and `rm -rf ~/.dotfiles`.
- **Local installs first, system packages as the forced fallback.**
  Homebrew (and Linuxbrew on Linux) installs to a user-writable prefix with
  no sudo required day-to-day, so it's the default. When brew is blocked by
  work policy, or a tool ships its own local installer (Starship), those are
  preferred over touching system packages — `apt`/`pacman`/`dnf` are the
  last resort, used automatically when nothing else is available.
- **Bash hands off to zsh.** If you land in an interactive bash session and
  zsh is installed, `shell/bootstrap.bash` execs into `zsh -l` — the same
  pattern as a manual `exec /bin/zsh` line, just made safe (interactive-only,
  skippable, never breaks a fresh non-interactive or zsh-less shell) and
  centralized so it's consistent across machines.

## Layout

```
install.sh / update.sh / uninstall.sh   entrypoints
lib/                         package abstraction + per-tool install helpers
shell/
  bootstrap.bash             sourced by .bashrc / .bash_profile
  bootstrap.zsh              sourced by .zshrc
  bootstrap.profile.sh       sourced by .zprofile / .bash_profile (login-only PATH setup)
  common/                    POSIX sh, shared by bash + zsh (os-detect, path, aliases)
  zsh/                       omz wiring, zsh options
  bash/                      bash-only fallback config (used if zsh isn't installed)
  local.*.example            per-machine override mechanism (copy, drop the .example)
config/starship.toml         prompt config
vim/vimrc, tmux/tmux.conf
fonts/install-fonts.sh       downloads a Nerd Font straight from upstream, no package manager
packages/                    Brewfile + apt/pacman/dnf reference lists
```

## Install

```sh
git clone <this-repo-url> ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Rc files always reference `$HOME/.dotfiles`, so cloning there is the
convention — but if you run `install.sh` from somewhere else (a different
clone path, or just testing it out of a working copy), it symlinks
`~/.dotfiles` to wherever it actually is rather than silently leaving the
rc files pointing nowhere. If `~/.dotfiles` already exists as something
else (a real directory, or a symlink elsewhere), it stops with an error
instead of guessing what you meant.

What it does: installs zsh/tmux/vim/git/curl (brew first, system package
fallback), installs Starship via its own local installer, installs
oh-my-zsh + `zsh-autosuggestions`/`zsh-syntax-highlighting`/`zsh-completions`
(without letting omz touch `.zshrc`), installs vim-plug and tmux's TPM,
downloads a Nerd Font into a user-local font dir, installs kubectl, k9s,
and kubelogin via their own official/upstream binary releases, links
Obsidian's bundled CLI into `~/.local/bin/obsidian` if the Obsidian app is
installed (macOS; on Linux Obsidian's own CLI registration already puts it
there), symlinks
`starship.toml`/`vimrc`/`tmux.conf`, then adds the one guarded block to
each rc file.

`kubelogin` here means [int128/kubelogin](https://github.com/int128/kubelogin),
a generic OIDC credential plugin for kubectl — not the unrelated,
Azure-specific `Azure/kubelogin` that happens to share the name. It's
installed as a plain `kubelogin` binary on `PATH`, referenced directly as
the `command` in a kubeconfig's `exec` auth provider — not registered as
a `kubectl`-plugin-style `kubectl oidc-login` subcommand.

Open a new terminal (or `exec $SHELL -l`) afterwards.

### Overrides for locked-down machines

```sh
DOTFILES_NO_BREW=1 ./install.sh              # skip Homebrew, go straight to apt/pacman/dnf
DOTFILES_NO_LOCAL_INSTALLERS=1 ./install.sh  # skip curl-based installers (Starship's own script, etc.)
DOTFILES_FONT=JetBrainsMono ./install.sh     # pick a different Nerd Font
```

Also respected at shell-startup time (export in your actual environment,
not just at install time):

```sh
DOTFILES_NO_EXEC_ZSH=1   # stay in bash even if zsh is installed
```

### No network / can't run scripts at all

`packages/apt.txt`, `packages/pacman.txt`, `packages/dnf.txt` are plain
package-name lists you can hand to the system package manager directly:

```sh
grep -v '^#' packages/apt.txt | xargs sudo apt-get install -y
```

## Update

```sh
~/.dotfiles/update.sh
```

`install.sh` is idempotent-safe to re-run, but deliberately not an
upgrader — it skips anything already present (e.g. `command -v zsh` short-
circuits before it would ever check for a newer version). `update.sh` is
the actual upgrade path: `brew upgrade`, oh-my-zsh's own upgrade script (or
`git pull`) plus a `git pull` for each zsh plugin, `vim +PlugUpdate`, and
TPM's `update_plugins all`. It only touches what this repo manages
directly — if a tool came from the system-package fallback
(`DOTFILES_NO_BREW=1`), update it through your OS's normal process instead;
this won't run a system-wide `apt`/`pacman`/`dnf` upgrade for you.

## Uninstall / start over

```sh
~/.dotfiles/uninstall.sh
```

Strips the guarded block back out of all four rc files. Installed tools
(Homebrew, oh-my-zsh, fonts, vim/tmux plugins) and the symlinked configs are
left alone on purpose — it prints the manual commands to remove those too if
you want a completely clean machine.

## Secrets

`install.sh` creates `shell/local.zsh` and `shell/local.bash` from their
`.example` templates on first run (never overwriting one that already
exists), locks them to mode `600`, and both are listed in `.gitignore`.
They're sourced last by `shell/bootstrap.zsh`/`bootstrap.bash`, so this is
where API keys, tokens, and any other per-machine-only exports go:

```sh
# shell/local.zsh
export GITHUB_TOKEN="ghp_..."
```

This is a deliberate choice, not a placeholder for something fancier
later: secrets live in plaintext on each machine and are never, under any
circumstances, committed — not even encrypted. An encrypted blob checked
into git is still a secret sitting in a remote's history forever, waiting
on whatever key or algorithm protects it to someday fail; this setup
can't be improved to that without an actual security tradeoff. The real
cost is that there's no sync — a new machine means writing this file
again by hand. If you want to eliminate *that* without touching git,
point these files at a password-manager CLI instead of literal values
(e.g. `export GITHUB_TOKEN="$(op read op://vault/item/token)"` for
1Password) — nothing sensitive would touch disk at all, at the cost of
needing that vault unlocked in every new shell.

`uninstall.sh` never touches these files, but `rm -rf ~/.dotfiles` (its
suggested full-cleanup step) deletes them along with everything else —
they were never in git, so that's the only copy. Back them up first if
you ever run that.

## Customizing

- Prompt: edit `config/starship.toml` (schema: https://starship.rs/config-schema.json)
- zsh plugins: edit the `plugins=(...)` array in `shell/zsh/omz.zsh`
- vim plugins: add `Plug '...'` lines in `vim/vimrc`, then `vim +PlugInstall`
- tmux plugins: add `set -g @plugin '...'` lines in `tmux/tmux.conf`, then `prefix + I`
- Per-machine secrets/tweaks: see [Secrets](#secrets) above.
