# Ensure ControlPath socket directory exists (see ssh/config.shared)
[[ -d ~/.ssh/sockets ]] || mkdir -p ~/.ssh/sockets

# Load SSH keys stored in macOS Keychain into the agent.
# Without this, keys only enter the agent when used for an SSH connection
# (due to AddKeysToAgent), so forwarded agents on remote hosts may be
# missing keys like the git signing key.
if [[ "$OSTYPE" == darwin* ]]; then
    ssh-add --apple-load-keychain 2>/dev/null &!
fi

# Reset mouse tracking after SSH without replacing Ghostty's `ssh()` wrapper.
# Ghostty needs its wrapper to install xterm-ghostty terminfo on remote hosts.
typeset -g _reset_mouse_tracking_after_ssh=0

_mark_ssh_for_mouse_reset() {
    [[ "$1" == ssh || "$1" == ssh\ * ]] || return 0
    _reset_mouse_tracking_after_ssh=1
}

_reset_mouse_tracking_after_ssh_command() {
    (( _reset_mouse_tracking_after_ssh )) || return 0
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
    _reset_mouse_tracking_after_ssh=0
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _mark_ssh_for_mouse_reset
add-zsh-hook precmd _reset_mouse_tracking_after_ssh_command
