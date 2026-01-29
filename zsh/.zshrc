#!/usr/bin/env zsh
# Interactive shell configuration

# Powerlevel10k instant prompt (must be near top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load shell options, completion styles, key bindings
for conf in "$ZDOTDIR"/conf.d/*.zsh(N); do
    source "$conf"
done

# Auto-load secrets via 1Password CLI (cached until reboot)
if (( $+commands[op] )); then
    _cache="${TMPDIR}zsh-secrets"
    _src="$ZDOTDIR/autoloaded_secrets.zsh"

    # Refresh if missing or secrets.zsh was modified
    if [[ ! -r "$_cache" || "$_src" -nt "$_cache" ]] && op inject --in-file "$_src" --out-file "$_cache.tmp" 2>/dev/null; then
        chmod 600 "$_cache.tmp" && mv "$_cache.tmp" "$_cache"
    fi
    
    [[ -r "$_cache" ]] && source "$_cache"
    unset _cache _src
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
fpath=(/opt/homebrew/opt/antidote/share/antidote/functions $fpath)
autoload -Uz antidote
if [[ ! "${zsh_plugins}.zsh" -nt "${zsh_plugins}.txt" ]]; then
    antidote bundle <"${zsh_plugins}.txt" >|"${zsh_plugins}.zsh"
fi
source "${zsh_plugins}.zsh"

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
# Powerlevel10k prompt
#
[[ -f "$ZDOTDIR/.p10k.zsh" ]] && source "$ZDOTDIR/.p10k.zsh"

#
# Tool integrations
#
eval "$(direnv hook zsh)"
eval "$(zoxide init zsh)"
source <(fzf --zsh)
