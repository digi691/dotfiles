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
install.sh / uninstall.sh   entrypoints
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

What it does: installs zsh/tmux/vim/git/curl (brew first, system package
fallback), installs Starship via its own local installer, installs
oh-my-zsh + `zsh-autosuggestions`/`zsh-syntax-highlighting`/`zsh-completions`
(without letting omz touch `.zshrc`), installs vim-plug and tmux's TPM,
downloads a Nerd Font into a user-local font dir, symlinks `starship.toml`/
`vimrc`/`tmux.conf`, then adds the one guarded block to each rc file.

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

## Uninstall / start over

```sh
~/.dotfiles/uninstall.sh
```

Strips the guarded block back out of all four rc files. Installed tools
(Homebrew, oh-my-zsh, fonts, vim/tmux plugins) and the symlinked configs are
left alone on purpose — it prints the manual commands to remove those too if
you want a completely clean machine.

## Customizing

- Prompt: edit `config/starship.toml` (schema: https://starship.rs/config-schema.json)
- zsh plugins: edit the `plugins=(...)` array in `shell/zsh/omz.zsh`
- vim plugins: add `Plug '...'` lines in `vim/vimrc`, then `vim +PlugInstall`
- tmux plugins: add `set -g @plugin '...'` lines in `tmux/tmux.conf`, then `prefix + I`
- Per-machine secrets/tweaks: copy `shell/local.zsh.example` → `shell/local.zsh`
  (or the `.bash` equivalent) — gitignored, sourced last.
