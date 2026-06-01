# Secrets management (server fallback)
# On local machines, secrets are loaded via direnv + use_op (see direnv/direnvrc)
# On servers without direnv/op, use $ZDOTDIR/secrets/local.zsh (plaintext, gitignored)

[[ -r "$ZDOTDIR/secrets/local.zsh" ]] && source "$ZDOTDIR/secrets/local.zsh"

# Run a command with sensitive 1Password secrets resolved on demand. Secrets
# registered in .envrc via `use op --lazy NAME op://...` or `use op --lazy <tpl>`
# are injected by `op run` only into this command's subprocess: never cached,
# never in your shell env, 1Password prompts at exec time.
#   oprun Rscript analysis.R
# To pass flags to `op run`, put them before a `--` separator (same convention as
# `op run` itself). e.g. if masking garbles an interactive REPL:
#   oprun --no-masking -- radian
oprun() {
    emulate -L zsh
    if ! command -v op >/dev/null 2>&1; then
        print -u2 "oprun: op (1Password CLI) not found"
        return 1
    fi
    if [[ -z "$OP_RUN_ENV_FILES" && -z "$OP_RUN_REFS" ]]; then
        print -u2 "oprun: no lazy secrets registered — add 'use op --lazy ...' to .envrc"
        return 1
    fi

    # Split args on `--`: before it goes to `op run`, after it is the command.
    # With no `--`, all args are the command, so the common `oprun <cmd>` needs no
    # separator. Not parsing op's flags ourselves lets value-taking flags (e.g.
    # --account Work) pass through intact.
    local -a run_opts cmd
    local a seen_sep=0
    for a in "$@"; do
        if (( seen_sep )); then
            cmd+=("$a")
        elif [[ "$a" == "--" ]]; then
            seen_sep=1
        else
            run_opts+=("$a")
        fi
    done
    if (( ! seen_sep )); then
        cmd=("${run_opts[@]}")
        run_opts=()
    fi
    if (( ! ${#cmd} )); then
        print -u2 "oprun: no command — usage: oprun [op-run flags --] <command> [args...]"
        return 1
    fi

    local -a env_args ref_env
    local f line
    for f in "${(@s.:.)OP_RUN_ENV_FILES}"; do
        [[ -n "$f" ]] && env_args+=(--env-file="$f")
    done
    for line in "${(@f)OP_RUN_REFS}"; do
        [[ -n "$line" ]] && ref_env+=("$line")
    done
    # ref_env entries (NAME=op://...) enter op run's own env so it resolves them;
    # `env` scopes them to this call so the raw refs never persist in the shell.
    env "${ref_env[@]}" op run "${run_opts[@]}" "${env_args[@]}" -- "${cmd[@]}"
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
