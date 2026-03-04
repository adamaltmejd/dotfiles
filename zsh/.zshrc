#!/usr/bin/env zsh
# Interactive shell configuration

# Load shell options, completion styles, key bindings
for conf in "$ZDOTDIR"/conf.d/*.zsh(N); do
    source "$conf"
done

# Auto-load secrets via 1Password CLI (cached until reboot)
if (( $+commands[op] )); then
    _cache="${TMPDIR}zsh-secrets"
    _src="$ZDOTDIR/autoloaded_secrets.zsh"

    # Refresh if missing or secrets.zsh was modified
    if [[ ! -r "$_cache" || "$_src" -nt "$_cache" ]]; then
        _tmp="$(mktemp "${TMPDIR}zsh-secrets.XXXXXX" 2>/dev/null)"
        if [[ -n "$_tmp" ]] && op inject --force --in-file "$_src" --out-file "$_tmp" 2>/dev/null; then
            chmod 600 "$_tmp" && mv "$_tmp" "$_cache"
        fi
        [[ -n "$_tmp" && -e "$_tmp" ]] && rm -f "$_tmp"
    fi
    
    [[ -r "$_cache" ]] && source "$_cache"
    unset _cache _src _tmp
fi

# Lazy-load secrets on demand via load_secrets()
load_secrets() {
    if (( $+commands[op] )); then
        source <(op inject --in-file "$ZDOTDIR/lazy_secrets.zsh")
    else
        echo "1Password CLI (op) not found." >&2
        return 1
    fi
}

#
# Antidote plugin manager
#
zsh_plugins="$ZDOTDIR/plugins"
[[ -f "${zsh_plugins}.txt" ]] || touch "${zsh_plugins}.txt"
if [[ -d /opt/homebrew/opt/antidote/share/antidote/functions ]]; then
    fpath=(/opt/homebrew/opt/antidote/share/antidote/functions $fpath)
    autoload -Uz antidote
    if (( $+functions[antidote] )); then
        if [[ ! "${zsh_plugins}.zsh" -nt "${zsh_plugins}.txt" ]]; then
            antidote bundle <"${zsh_plugins}.txt" >|"${zsh_plugins}.zsh"
        fi
        source "${zsh_plugins}.zsh"
    fi
fi

#
# Completions
#
autoload -Uz compinit
if [[ -n "$ZDOTDIR"/.zcompdump(#qN.mh+24) ]]; then
    compinit -d "$ZDOTDIR/.zcompdump"
else
    compinit -C -d "$ZDOTDIR/.zcompdump"
fi

#
# Tool integrations
#
if (( $+commands[starship] )); then
    eval "$(starship init zsh)"

    # Transient prompt — collapse previous prompts to ❯
    zle-line-init() {
        [[ $CONTEXT == start ]] || return 0
        while true; do
            zle .recursive-edit
            local -i ret=$?
            [[ $ret == 0 && $KEYS == $'\4' ]] || break
            [[ -o ignore_eof ]] || exit 0
        done
        local saved_prompt=$PROMPT saved_rprompt=$RPROMPT
        PROMPT='%(?.%F{green}.%F{red})❯%f ' RPROMPT=''
        zle .reset-prompt
        PROMPT=$saved_prompt RPROMPT=$saved_rprompt
        if (( ret )); then
            zle .send-break
        else
            zle .accept-line
        fi
        return ret
    }
    zle -N zle-line-init
fi
if (( $+commands[direnv] )); then
    eval "$(direnv hook zsh)"
fi
if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi
if (( $+commands[fzf] )); then
    source <(fzf --zsh)
fi
