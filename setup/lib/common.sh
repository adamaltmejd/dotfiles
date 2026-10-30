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

# The generated source expands these variables when the shell starts.
# shellcheck disable=SC2016
bootstrap_bashrc_content() {
    local dotfiles_dir="$1"
    local xdg_config_home="$2"
    local profile="${3:-}"
    printf '# Managed by dotfiles setup.sh\n'
    printf 'export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-%q}\n' "$xdg_config_home"
    printf 'export DOTFILES_DIR=${DOTFILES_DIR:-%q}\n' "$dotfiles_dir"
    printf 'export DOTFILES_PROFILE=${DOTFILES_PROFILE:-%q}\n' "$profile"
    printf 'source "$DOTFILES_DIR/bash/bashrc"\n'
}

bootstrap_bash_profile_content() {
    cat <<'EOF'
# Managed by dotfiles setup.sh
# Bash does not read .bashrc for login shells unless requested here.
[[ ! -r "$HOME/.bashrc" ]] || source "$HOME/.bashrc"
EOF
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
    local feat_remote_ssh_local=0 feat_remote_ssh_server=0

    # Select defaults for profile
    local feat_starship feat_direnv feat_smartcli feat_r feat_claude
    local feat_remote_ssh
    case "$profile" in
        local)
            feat_starship=$feat_starship_local
            feat_direnv=$feat_direnv_local
            feat_smartcli=$feat_smartcli_local
            feat_r=$feat_r_local
            feat_claude=$feat_claude_local
            feat_remote_ssh=$feat_remote_ssh_local
            ;;
        server)
            feat_starship=$feat_starship_server
            feat_direnv=$feat_direnv_server
            feat_smartcli=$feat_smartcli_server
            feat_r=$feat_r_server
            feat_claude=$feat_claude_server
            feat_remote_ssh=$feat_remote_ssh_server
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
            REMOTE_SSH) feat_remote_ssh="$val" ;;
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
DOTFILES_FEAT_REMOTE_SSH=$feat_remote_ssh
EOF
}
