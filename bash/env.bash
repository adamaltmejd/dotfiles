# shellcheck shell=bash
# Environment only: safe for login shells, SSH commands, and repeated sourcing.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export DOTFILES_DIR="${DOTFILES_DIR:-$XDG_CONFIG_HOME}"

# /etc/profile already runs macOS path_helper for login shells. Homebrew also
# needs initialization for SSH commands and interactive non-login shells.
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv bash)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv bash)"
fi

export BUN_INSTALL="$XDG_DATA_HOME/bun"
export BUN_INSTALL_CACHE_DIR="$XDG_CACHE_HOME/bun"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CARGO_HOME="$XDG_DATA_HOME/cargo"

_dotfiles_path() {
    local entry joined=""
    local -a entries inherited
    IFS=: read -r -a inherited <<< "${PATH:-/usr/bin:/bin}"
    entries=("$HOME/.local/bin" "$BUN_INSTALL/bin" "$CARGO_HOME/bin" "${inherited[@]}")
    [[ -n ${HOMEBREW_PREFIX:-} ]] && entries+=("$HOMEBREW_PREFIX/opt/rustup/bin")
    [[ "$OSTYPE" == darwin* ]] && entries+=("/Applications/Obsidian.app/Contents/MacOS")
    for entry in "${entries[@]}"; do
        [[ -n "$entry" ]] || continue
        case ":$joined:" in
            *:"$entry":*) ;;
            *) joined="${joined:+$joined:}$entry" ;;
        esac
    done
    export PATH="$joined"
}
_dotfiles_path
unset -f _dotfiles_path

if [[ -n ${SSH_CONNECTION:-} ]]; then
    export EDITOR=vi VISUAL=vi
else
    export EDITOR="code --wait" VISUAL="code --wait"
fi
if [[ "$OSTYPE" == darwin* ]]; then
    export BROWSER=open
    export SSH_SK_PROVIDER=/usr/local/lib/sk-libfido2.dylib
    export SSH_ASKPASS="$XDG_CONFIG_HOME/ssh/ssh-askpass"
fi
export PAGER=less
export LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 LC_ALL=en_US.UTF-8
export TZ=Europe/Stockholm
export LESS="--raw-control-chars --ignore-case --squeeze-blank-lines --hilite-unread"
export STARSHIP_CONFIG="$DOTFILES_DIR/bash/starship.toml"
export ANSIBLE_VAULT_PASSWORD_FILE="$XDG_CONFIG_HOME/ansible/vault-password-file"
export UV_CACHE_DIR=/tmp/uv-cache
export PINFOLD_PROFILE=full
