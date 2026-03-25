#!/usr/bin/env zsh
# Sourced on all shell invocations. Sets environment variables only.
# This file is sourced by the bootstrap ~/.zshenv after XDG vars are set.

# On macOS, /etc/zprofile runs path_helper which resets PATH order.
# Disable global rc files and call path_helper ourselves first.
if [[ "$OSTYPE" == darwin* ]]; then
  unsetopt GLOBAL_RCS
fi

#
# PATH
#
# Apple system paths
if [[ -x /usr/libexec/path_helper ]]; then
  eval "$(/usr/libexec/path_helper -s)"
fi
# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Additional paths
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/.bun/bin"
  $path
  "/Applications/Obsidian.app/Contents/MacOS"
)

#
# Editors
#
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR="vi"
    export VISUAL="vi"
else
    export EDITOR="code --wait"
    export VISUAL="code --wait"
fi

[[ "$OSTYPE" == darwin* ]] && export BROWSER="open"
export PAGER="less"

#
# Locale
#
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TZ="Europe/Stockholm"

#
# Less
#
export LESS="--raw-control-chars --ignore-case --squeeze-blank-lines --hilite-unread"

#
# SSH (YubiKey FIDO support)
#
if [[ "$OSTYPE" == darwin* ]]; then
    export SSH_SK_PROVIDER=/usr/local/lib/sk-libfido2.dylib
    export SSH_ASKPASS="$XDG_CONFIG_HOME/ssh/ssh-askpass"
fi

#
# Additional configs
#
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/zsh/starship.toml"
export ANSIBLE_VAULT_PASSWORD_FILE="$XDG_CONFIG_HOME/ansible/vault-password-file"

# UV Cache needs to go in /tmp instead of ~/.cache for codex sandboxing to not error
export UV_CACHE_DIR=/tmp/uv-cache
