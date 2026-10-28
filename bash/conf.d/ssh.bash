mkdir -p "$HOME/.ssh/sockets"
if [[ "$OSTYPE" == darwin* ]]; then
    ssh-add --apple-load-keychain 2>/dev/null &
    disown "$!" 2>/dev/null || true
fi

# Reset terminal mouse modes at the prompt, without wrapping Ghostty's ssh()
# function or installing a DEBUG/preexec trap that competes with Starship.
_dotfiles_reset_mouse() {
    local status=$?
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
    return "$status"
}
