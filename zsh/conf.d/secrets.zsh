# Secrets management (server fallback)
# On local machines, secrets are loaded via direnv + use_op (see direnv/direnvrc)
# On servers without direnv/op, use $ZDOTDIR/secrets/local.zsh (plaintext, gitignored)

[[ -r "$ZDOTDIR/secrets/local.zsh" ]] && source "$ZDOTDIR/secrets/local.zsh"

# Run a command with sensitive 1Password secrets resolved on demand. Secrets
# registered in .envrc via `use op --lazy NAME op://...` or `use op --lazy <tpl>`
# are injected by `op run` only into this command's subprocess: never cached,
# never in your shell env, 1Password prompts at exec time.
#   oprun Rscript analysis.R
# Leading flags are forwarded to `op run`; parsing stops at the first non-flag arg
# or an explicit `--`, so the command keeps any `--` of its own:
#   oprun --no-masking -- radian   # if masking garbles an interactive REPL
#   oprun rg -- pattern            # runs `rg -- pattern` unchanged
# op flags taking a value must use --flag=value form (e.g. --account=Work).
oprun() {
    emulate -L zsh
    if ! command -v op >/dev/null 2>&1; then
        print -u2 "oprun: op (1Password CLI) not found"
        return 1
    fi
    if [[ -z "$OP_RUN_LAZY" ]]; then
        print -u2 "oprun: no lazy secrets registered — add 'use op --lazy ...' to .envrc"
        return 1
    fi

    # getopt-style: consume leading op-run flags, stop at the first non-flag arg
    # or an explicit `--` (consumed). The rest in $@ is the command, passed
    # verbatim — so a command with its own `--` (e.g. `oprun rg -- pattern`) works.
    local -a run_opts
    while (( $# )); do
        case "$1" in
            --) shift; break ;;
            -*) run_opts+=("$1"); shift ;;
            *)  break ;;
        esac
    done
    if (( ! $# )); then
        print -u2 "oprun: no command — usage: oprun [op-run flags] [--] <command> [args...]"
        return 1
    fi

    # Stream every registered source — templates (f) and inline refs (r) — into a
    # single env-file in declaration order. op run resolves the op:// refs into the
    # child only, and is last-wins across and within env-files, so a later --lazy
    # override beats an earlier one. Process substitution keeps the refs off disk.
    op run "${run_opts[@]}" --env-file=<(
        local entry
        for entry in "${(@f)OP_RUN_LAZY}"; do
            case "$entry" in
                f$'\t'*) entry="${entry#f$'\t'}"
                    if [[ -r "$entry" ]]; then cat -- "$entry"; print
                    else print -u2 "oprun: lazy template not readable: $entry"; fi ;;
                r$'\t'*) print -r -- "${entry#r$'\t'}" ;;
            esac
        done
    ) -- "$@"
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
