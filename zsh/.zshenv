#!/usr/bin/env zsh
# Sourced on all shell invocations. Sets environment variables only.
# This file is sourced by the bootstrap ~/.zshenv after XDG vars are set.

# By default /etc/zprofile is loaded after ~/.zshenv, and /usr/libexec/path_helper resets path
unsetopt GLOBAL_RCS # disabled /etc/zprofile loading

#
# PATH
#
# Apple defaults
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval $(/usr/libexec/path_helper -s)
fi
# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval $(/opt/homebrew/bin/brew shellenv)
fi

# Additional paths
PATH="$HOME/.bun/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"

#
# Editors
#
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR="vi"
    export VISUAL="vi"
else
    export EDITOR="code"
    export VISUAL="code"
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
export SSH_SK_PROVIDER=/usr/local/lib/sk-libfido2.dylib
export SSH_ASKPASS="$XDG_CONFIG_HOME/ssh/ssh-askpass"

#
# Additional configs
#
export ANSIBLE_VAULT_PASSWORD_FILE="$XDG_CONFIG_HOME/ansible/vault-password-file"