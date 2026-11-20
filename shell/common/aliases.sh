# POSIX sh. Aliases that need to behave the same on macOS (BSD userland) and Linux (GNU userland).
if [ "$DOTFILES_OS" = "macos" ]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi

alias ll='ls -lh'
alias la='ls -lha'
alias grep='grep --color=auto'
alias vi='vim'
alias tmux='tmux -2'
alias reload='exec "$SHELL" -l'
