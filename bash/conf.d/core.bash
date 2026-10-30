# Interactive options and Readline. Do not enable script strict mode here.
shopt -s histappend checkwinsize autocd
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTFILE="$XDG_STATE_HOME/bash/history"
mkdir -p "${HISTFILE%/*}"

# Append our new entries before reading other sessions' entries. Keep the prior
# command's status so prompt integrations still report failures correctly.
_dotfiles_history_sync() {
    local status=$?
    history -a
    history -n
    return "$status"
}

bind 'set editing-mode emacs'
bind 'set completion-ignore-case on'
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e\e[D": backward-word'
bind '"\e\e[C": forward-word'

if feat smartcli && command -v eza >/dev/null 2>&1; then
    alias ls='eza' l='eza -l' la='eza -la' ll='eza -l' lsd='eza -lD' tree='eza --tree'
fi
if feat smartcli && command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'" MANROFFOPT=-c
fi
alias grep='grep --color=auto'
alias sudo='sudo '
alias reload='exec "$BASH" -l'

mkd() { (( $# )) && mkdir -p -- "$@" && { cd -- "${!#}" || return; }; }
o() {
    if (( $# )); then open "$@"; else open .; fi
}
fs() {
    local arg=-sh
    local -a paths=("$@")
    du -b /dev/null &>/dev/null && arg=-sbh
    if (( ! $# )); then
        # Glob in a subshell so nullglob does not change the caller's options.
        (shopt -s nullglob; du "$arg" -- .[^.]* ./*)
    else
        du "$arg" -- "${paths[@]}"
    fi
}
echoerr() { printf '%s\n' "$*" >&2; }
fman() {
    local page
    page="$(man -k . | fzf --preview 'man {1}' | awk '{print $1}' | head -n 1)"
    [[ -n "$page" ]] && man "$page"
}
tips() { command cat "$DOTFILES_DIR/bash/tips.txt"; }
_tips_marker="$XDG_STATE_HOME/bash/tips-$(date +%Y-%m-%d)"
if [[ ! -f "$_tips_marker" ]]; then
    touch "$_tips_marker"
    tips
fi
unset _tips_marker

# Other open shells can still reintroduce their in-memory history on exit.
erase_history() {
    history -c
    history -w
}
