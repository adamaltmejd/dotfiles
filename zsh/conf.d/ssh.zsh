# Ensure ControlPath socket directory exists (see ssh/config)
[[ -d ~/.ssh/sockets ]] || mkdir -p ~/.ssh/sockets

# Load SSH keys stored in macOS Keychain into the agent.
# Without this, keys only enter the agent when used for an SSH connection
# (due to AddKeysToAgent), so forwarded agents on remote hosts may be
# missing keys like the git signing key.
ssh-add --apple-load-keychain 2>/dev/null &!

# Reset mouse tracking after SSH (prevents garbage on click after ungraceful disconnect)
ssh() {
    command ssh "$@"
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
}
