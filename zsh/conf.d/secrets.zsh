# Secrets management (server fallback)
# On local machines, secrets are loaded via direnv + use_op (see direnv/direnvrc)
# On servers without direnv/op, use $ZDOTDIR/secrets/local.zsh (plaintext, gitignored)

[[ -r "$ZDOTDIR/secrets/local.zsh" ]] && source "$ZDOTDIR/secrets/local.zsh"

# Run a command with sensitive 1Password secrets resolved on demand. Secrets
# registered in .envrc via `use op --lazy NAME op://...` or `use op --lazy <tpl>`
# are injected by `op run` only into this command's subprocess: never cached,
# never in your shell env, 1Password prompts at exec time. Leading flags are
# forwarded to `op run` (e.g. `oprun --no-masking radian` if masking breaks a REPL).
#   oprun Rscript analysis.R
oprun() {
    emulate -L zsh
    if [[ -z "$OP_RUN_ENV_FILES" && -z "$OP_RUN_REFS" ]]; then
        print -u2 "oprun: no lazy secrets registered — add 'use op --lazy ...' to .envrc"
        return 1
    fi
    local -a run_opts env_args ref_env
    while [[ "$1" == -* ]]; do run_opts+=("$1"); shift; done
    local f line
    for f in "${(@s.:.)OP_RUN_ENV_FILES}"; do
        [[ -n "$f" ]] && env_args+=(--env-file="$f")
    done
    for line in "${(@f)OP_RUN_REFS}"; do
        [[ -n "$line" ]] && ref_env+=("$line")
    done
    # ref_env entries (NAME=op://...) enter op run's own env so it resolves them;
    # `env` scopes them to this call so the raw refs never persist in the shell.
    env "${ref_env[@]}" op run "${run_opts[@]}" "${env_args[@]}" -- "$@"
}

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
#
# Sensitive secrets (never cached, 1Password prompts on use):
#   use op --lazy MY_SECRET op://vault/item/field
#   use op --lazy .sensitive.env.tpl
#   then run:  oprun <command>
EOF

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        if ! git check-ignore -q .envrc 2>/dev/null; then
            echo '.envrc' >> .gitignore
        fi
    fi

    direnv allow
    echo "created .envrc and added it to .gitignore"
}
