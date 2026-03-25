#!/usr/bin/env bash

set -euo pipefail

APPLY="${APPLY:-0}"

log_info() {
    printf '[info] %s\n' "$*"
}

log_warn() {
    printf '[warn] %s\n' "$*" >&2
}

log_error() {
    printf '[error] %s\n' "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

phase() {
    printf '\n==> %s\n' "$*"
}

timestamp() {
    date +%Y%m%d-%H%M%S
}

run_or_print() {
    if [[ "$APPLY" -eq 1 ]]; then
        "$@"
    else
        printf '[dry-run]'
        for arg in "$@"; do
            printf ' %q' "$arg"
        done
        printf '\n'
    fi
}

ensure_dir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return 0
    fi
    run_or_print mkdir -p "$dir"
}

set_mode() {
    local path="$1"
    local mode="$2"
    if [[ "$APPLY" -eq 1 ]]; then
        [[ -e "$path" || -L "$path" ]] && chmod "$mode" "$path"
    else
        printf '[dry-run] chmod %s %s\n' "$mode" "$path"
    fi
}

bootstrap_zshenv_content() {
    local dotfiles_dir="$1"
    local xdg_config_home="$2"
    local profile="${3:-}"
    cat <<EOF_INNER
#!/usr/bin/env zsh
# Managed by dotfiles setup.sh
export XDG_CONFIG_HOME="\${XDG_CONFIG_HOME:-$xdg_config_home}"
export XDG_DATA_HOME="\${XDG_DATA_HOME:-\$HOME/.local/share}"
export XDG_STATE_HOME="\${XDG_STATE_HOME:-\$HOME/.local/state}"
export XDG_CACHE_HOME="\${XDG_CACHE_HOME:-\$HOME/.cache}"

export DOTFILES_DIR="\${DOTFILES_DIR:-$dotfiles_dir}"
export DOTFILES_PROFILE="${profile}"
export ZDOTDIR="\$DOTFILES_DIR/zsh"
[[ -f "\$ZDOTDIR/.zshenv" ]] && source "\$ZDOTDIR/.zshenv"
EOF_INNER
}

# Build the profile feature-flag file content.
# Usage: build_profile_content <profile> [FEAT=val ...]
build_profile_content() {
    local profile="$1"
    shift

    # Defaults per feature (local server)
    local feat_starship_local=1 feat_starship_server=0
    local feat_direnv_local=1  feat_direnv_server=0
    local feat_smartcli_local=1 feat_smartcli_server=0
    local feat_r_local=1       feat_r_server=0
    local feat_claude_local=1  feat_claude_server=0

    # Select defaults for profile
    local feat_starship feat_direnv feat_smartcli feat_r feat_claude
    case "$profile" in
        local)
            feat_starship=$feat_starship_local
            feat_direnv=$feat_direnv_local
            feat_smartcli=$feat_smartcli_local
            feat_r=$feat_r_local
            feat_claude=$feat_claude_local
            ;;
        server)
            feat_starship=$feat_starship_server
            feat_direnv=$feat_direnv_server
            feat_smartcli=$feat_smartcli_server
            feat_r=$feat_r_server
            feat_claude=$feat_claude_server
            ;;
        *)
            die "Unknown profile '$profile' in build_profile_content"
            ;;
    esac

    # Apply overrides (FEAT_NAME=val)
    local override
    for override in "$@"; do
        local key="${override%%=*}"
        local val="${override#*=}"
        case "$key" in
            STARSHIP) feat_starship="$val" ;;
            DIRENV)   feat_direnv="$val" ;;
            SMARTCLI) feat_smartcli="$val" ;;
            R)        feat_r="$val" ;;
            CLAUDE)   feat_claude="$val" ;;
            *)        die "Unknown feature override: $key" ;;
        esac
    done

    cat <<EOF
# Managed by dotfiles setup.sh — do not edit
DOTFILES_PROFILE=$profile
DOTFILES_FEAT_STARSHIP=$feat_starship
DOTFILES_FEAT_DIRENV=$feat_direnv
DOTFILES_FEAT_SMARTCLI=$feat_smartcli
DOTFILES_FEAT_R=$feat_r
DOTFILES_FEAT_CLAUDE=$feat_claude
EOF
}
