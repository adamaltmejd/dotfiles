# Secrets management
# Templates in $ZDOTDIR/secrets/ contain op:// references resolved at runtime
# For machines without op, use $ZDOTDIR/secrets/local.zsh (plaintext, gitignored)

# Plaintext fallback (no op needed)
[[ -r "$ZDOTDIR/secrets/local.zsh" ]] && source "$ZDOTDIR/secrets/local.zsh"

# 1Password CLI
(( $+commands[op] )) || return

# Auto-load: resolved once, cached in $TMPDIR until reboot
_cache="${TMPDIR}zsh-secrets"
_src="$ZDOTDIR/secrets/autoload.zsh"

if [[ ! -r "$_cache" || "$_src" -nt "$_cache" ]]; then
    _tmp="$(mktemp "${TMPDIR}zsh-secrets.XXXXXX" 2>/dev/null)"
    if [[ -n "$_tmp" ]] && op inject --force --in-file "$_src" --out-file "$_tmp" 2>/dev/null; then
        chmod 600 "$_tmp" && mv "$_tmp" "$_cache"
    fi
    [[ -n "$_tmp" && -e "$_tmp" ]] && rm -f "$_tmp"
fi

[[ -r "$_cache" ]] && source "$_cache"
unset _cache _src _tmp

# Lazy-load: resolved on demand via load_secrets()
load_secrets() {
    source <(op inject --in-file "$ZDOTDIR/secrets/lazy.zsh")
}
