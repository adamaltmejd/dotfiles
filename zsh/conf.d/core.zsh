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

# -- Completion behavior --
# Completers to use: previous list, expand aliases/globs, standard, pattern match, ignored, fuzzy
zstyle ':completion:*' completer _oldlist _expand _complete _match _ignored _approximate
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'         # Case-insensitive matching
zstyle ':completion:*' insert-tab pending                   # Tab inserts tab when line empty
zstyle ':completion:*' rehash true                          # Auto-detect new executables in PATH
zstyle ':completion:*' accept-exact '*(N)'                  # Accept exact match without menu
zstyle ':completion:*' squeeze-slashes true                 # Treat // as / in paths
zstyle ':completion:*' complete-options true                # Complete options after = in --opt=val

# -- Caching (for slow completions like apt, brew) --
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"

# -- Fuzzy matching / correction --
zstyle ':completion:*:approximate:' max-errors 'reply=( $((($#PREFIX+$#SUFFIX)/3 )) numeric )'  # 1 error per 3 chars
zstyle ':completion:*:correct:*' insert-unambiguous true    # Insert common prefix
zstyle ':completion:*:correct:*' original true              # Offer original as option
zstyle ':completion:correct:' prompt 'correct to: %e'

# -- Display formatting --
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}                              # Use LS_COLORS
zstyle ':completion:*:descriptions' format $'%{\e[0;31m%}completing %B%d%b%{\e[0m%}'       # Section headers
zstyle ':completion:*:corrections' format $'%{\e[0;31m%}%d (errors: %e)%{\e[0m%}'          # Fuzzy match info
zstyle ':completion:*:warnings' format $'%{\e[0;31m%}No matches for:%{\e[0m%} %d'          # No matches warning
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*' verbose true                         # Show descriptions
zstyle ':completion:*:-command-:*:' verbose false           # ...except for commands (too noisy)

# -- Grouping and menus --
zstyle ':completion:*:matches' group 'yes'                  # Group matches by type
zstyle ':completion:*' group-name ''                        # Use tag name as group name
zstyle ':completion:*' menu select=5                        # Show menu if 5+ matches
zstyle ':completion:*' select-prompt '%SScrolling: %p%s'    # Show position in long lists

# -- Options and descriptions --
zstyle ':completion:*:options' auto-description '%d'        # Describe options without descriptions
zstyle ':completion:*:options' description 'yes'

# -- Directory completion --
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select   # Menu for cd dir stack
zstyle ':completion:*' special-dirs ..                          # Complete .. as parent dir
zstyle ':completion:*:expand:*' tag-order all-expansions        # Show all glob expansions

# -- History word completion --
zstyle ':completion:*:history-words' list false             # Don't list, just complete
zstyle ':completion:*:history-words' menu yes               # Use menu selection
zstyle ':completion:*:history-words' remove-all-dups yes    # No duplicates
zstyle ':completion:*:history-words' stop yes               # Stop at word boundaries

# -- Process completion (kill, etc.) --
zstyle ':completion:*:processes' command 'ps -au$USER'
zstyle ':completion:*:processes-names' command 'ps c -u ${USER} -o command | uniq'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'  # Highlight PIDs
zstyle ':completion:*:*:kill:*' insert-ids single           # Only insert PID if unambiguous
zstyle ':completion:*:*:kill:*' menu yes select             # Menu for kill

# -- Man page completion --
zstyle ':completion:*:manuals' separate-sections true       # Group by section
zstyle ':completion:*:manuals.*' insert-sections true       # Include section number
zstyle ':completion:*:man:*' menu yes select

# -- Array subscript completion --
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# -- Ignore patterns --
zstyle ':completion:*:complete:-command-::commands' ignored-patterns '(aptitude-*|*\~)'  # Hide aptitude-* and backup files
zstyle ':completion:*:*:zcompile:*' ignored-patterns '(*~|*.zwc)'                        # Hide compiled zsh files
zstyle ':completion::(^approximate*):*:functions' ignored-patterns '_*'                  # Hide internal _functions

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

# Use bat as man pager
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

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

# Fuzzy-find man pages
fman() {
    man -k . | fzf --preview 'man {1}' | awk '{print $1}' | xargs -r man
}

# Erase current session history
erase_history() {
    local HISTSIZE=0
}

zshaddhistory_erase_history() {
    [[ $1 != [[:space:]]#erase_history[[:space:]]# ]]
}
zshaddhistory_functions+=(zshaddhistory_erase_history)
