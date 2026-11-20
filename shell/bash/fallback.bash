# Only loaded when zsh isn't available — e.g. a hardened box where you can't
# install anything beyond what's already there.
HISTCONTROL=ignoredups:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
