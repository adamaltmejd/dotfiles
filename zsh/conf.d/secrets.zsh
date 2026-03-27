# Secrets management (server fallback)
# On local machines, secrets are loaded via direnv + use_op (see direnv/direnvrc)
# On servers without direnv/op, use $ZDOTDIR/secrets/local.zsh (plaintext, gitignored)

[[ -r "$ZDOTDIR/secrets/local.zsh" ]] && source "$ZDOTDIR/secrets/local.zsh"

direnv-init() {
    if [[ -f .envrc ]]; then
        echo "error: .envrc already exists" >&2
        return 1
    fi

    cat > .envrc <<'EOF'
use op ~/.config/zsh/secrets/base.env

# Project-specific secrets:
#   use op MY_SECRET op://vault/item/field
#
# Bulk secrets from a template file:
#   use op .secrets.env.tpl
EOF

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        if ! git check-ignore -q .envrc 2>/dev/null; then
            echo '.envrc' >> .gitignore
        fi
    fi

    direnv allow
    echo "created .envrc and added it to .gitignore"
}
