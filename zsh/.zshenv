#!/usr/bin/env zsh
# Sourced on all shell invocations. Sets environment variables only.
# This file is sourced by the bootstrap ~/.zshenv after XDG vars are set.

# Disable global zsh config to ensure consistent PATH ordering
unsetopt GLOBAL_RCS

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
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

#
# GPG (for git signing)
#
export GPG_TTY="$(tty)"

#
# SSH (YubiKey FIDO support)
#
export SSH_SK_PROVIDER=/usr/local/lib/sk-libfido2.dylib
export SSH_ASKPASS="$XDG_CONFIG_HOME/ssh/ssh-askpass"

#
# PATH
#
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
PATH="/opt/homebrew/opt/python/libexec/bin:$PATH"
PATH="/Library/Frameworks/R.framework/Resources:$PATH"
PATH="/Library/TeX/texbin:$PATH"
PATH="$HOME/.bun/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
export PATH

#
# MANPATH
#
MANPATH="/usr/share/man"
MANPATH="/Library/TeX/Distributions/.DefaultTeX/Contents/Man:$MANPATH"
MANPATH="/opt/X11/share/man:$MANPATH"
export MANPATH

#
# CDPATH
#
export CDPATH=".:~:$HOME/Library/CloudStorage/Dropbox/Research"

#
# Homebrew
#
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

#
# macOS path_helper (adds system paths)
#
if [[ -x /usr/libexec/path_helper ]]; then
    eval "$(/usr/libexec/path_helper -s)"
fi
