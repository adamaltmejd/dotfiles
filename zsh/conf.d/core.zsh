#!/usr/bin/env zsh
# Core shell configuration: options, history, completions, key bindings, aliases

#
# Shell Options
#
setopt APPEND_HISTORY         # Append to history file
setopt SHARE_HISTORY          # Share history between sessions
setopt EXTENDED_HISTORY       # Save timestamp and duration
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate entries
setopt HIST_IGNORE_SPACE      # Ignore commands starting with space
setopt HIST_REDUCE_BLANKS     # Remove trailing whitespace
setopt HIST_FIND_NO_DUPS      # Don't show duplicates in search
setopt HIST_VERIFY            # Don't execute immediately on history expansion
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicates first when trimming

setopt AUTO_CD                # cd by typing directory name
setopt AUTO_PUSHD             # Push old directory onto stack
setopt PUSHD_IGNORE_DUPS      # Don't push duplicates
setopt EXTENDED_GLOB          # Extended globbing (#, ~, ^)
setopt NO_GLOB_DOTS           # Don't match dotfiles with *
setopt NO_SH_WORD_SPLIT       # Use zsh word splitting
setopt COMPLETE_IN_WORD       # Complete from cursor position
setopt HASH_LIST_ALL          # Hash command path on completion
setopt LONG_LIST_JOBS         # Show PID in job listings
setopt NOTIFY                 # Report job status immediately
setopt NO_BEEP                # No terminal bell

#
# History
#
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"

# Ensure history directory exists
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

#
# Completion Styles
#
zstyle ':completion:*:approximate:' max-errors 'reply=( $((($#PREFIX+$#SUFFIX)/3 )) numeric )'
zstyle ':completion:*:complete:-command-::commands' ignored-patterns '(aptitude-*|*\~)'
zstyle ':completion:*' completer _oldlist _expand _complete _match _ignored _approximate
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' insert-tab pending
zstyle ':completion:*' rehash true

zstyle ':completion:*:correct:*' insert-unambiguous true
zstyle ':completion:*:corrections' format $'%{\e[0;31m%}%d (errors: %e)%{\e[0m%}'
zstyle ':completion:*:correct:*' original true
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format $'%{\e[0;31m%}completing %B%d%b%{\e[0m%}'

zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:expand:*' tag-order all-expansions
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' stop yes

zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=5
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:processes' command 'ps -au$USER'
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters
zstyle ':completion:*' verbose true
zstyle ':completion:*:-command-:*:' verbose false
zstyle ':completion:*:warnings' format $'%{\e[0;31m%}No matches for:%{\e[0m%} %d'
zstyle ':completion:*:*:zcompile:*' ignored-patterns '(*~|*.zwc)'
zstyle ':completion:correct:' prompt 'correct to: %e'
zstyle ':completion::(^approximate*):*:functions' ignored-patterns '_*'
zstyle ':completion:*:processes-names' command 'ps c -u ${USER} -o command | uniq'
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.*' insert-sections true
zstyle ':completion:*:man:*' menu yes select
zstyle ':completion:*' special-dirs ..

#
# Key Bindings
#
bindkey -e  # Emacs bindings

bindkey "^A" beginning-of-line
bindkey "^B" backward-char
bindkey "^E" end-of-line
bindkey "^D" delete-char
bindkey "^K" kill-whole-line
bindkey "^N" down-line-or-search
bindkey "^P" up-line-or-search
bindkey "^R" history-incremental-pattern-search-backward
bindkey "^F" history-incremental-pattern-search-forward

bindkey "^[^[[D" backward-word  # Alt-Left
bindkey "^[^[[C" forward-word   # Alt-Right

bindkey '^[[A' history-beginning-search-backward  # Up
bindkey '^[[B' history-beginning-search-forward   # Down

#
# Core Aliases
#

# Modern ls (eza)
alias ls="eza"
alias l="eza -l"
alias la="eza -la"
alias ll="eza -l"
alias lsd="eza -lD"
alias tree="eza --tree"

# Modern cat (bat)
alias cat="bat --paging=never"

# Grep with color
alias grep='grep --color=auto'

# Enable aliases with sudo
alias sudo='sudo '

# Reload shell
alias reload="exec $SHELL -l"

#
# Core Functions
#

# Create directory and cd into it
mkd() {
    mkdir -p "$@" && cd "$_"
}

# Open current directory or given path
o() {
    if [[ $# -eq 0 ]]; then
        open .
    else
        open "$@"
    fi
}

# File/directory size
fs() {
    if du -b /dev/null &>/dev/null; then
        local arg=-sbh
    else
        local arg=-sh
    fi
    if [[ -n "$@" ]]; then
        du $arg -- "$@"
    else
        du $arg .[^.]* ./*
    fi
}

# Echo to stderr
echoerr() {
    printf "%s\n" "$*" >&2
}

# Erase current session history
erase_history() {
    local HISTSIZE=0
}

zshaddhistory_erase_history() {
    [[ $1 != [[:space:]]#erase_history[[:space:]]# ]]
}
zshaddhistory_functions+=(zshaddhistory_erase_history)
