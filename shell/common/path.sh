# POSIX sh. Puts local-first install locations ahead of system package dirs.
for dir in "$HOME/.local/bin" "$HOME/bin"; do
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) PATH="$dir:$PATH" ;;
  esac
done

case "$DOTFILES_OS" in
  macos)
    if [ -d /opt/homebrew/bin ]; then
      case ":$PATH:" in
        *":/opt/homebrew/bin:"*) ;;
        *) PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" ;;
      esac
    fi
    ;;
  linux)
    for brewdir in /home/linuxbrew/.linuxbrew/bin "$HOME/.linuxbrew/bin"; do
      if [ -d "$brewdir" ]; then
        case ":$PATH:" in
          *":$brewdir:"*) ;;
          *) PATH="$brewdir:$PATH" ;;
        esac
      fi
    done
    ;;
esac

export PATH
