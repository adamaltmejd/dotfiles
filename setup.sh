#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=setup/lib/common.sh
source "$SCRIPT_DIR/setup/lib/common.sh"
# shellcheck source=setup/lib/detect.sh
source "$SCRIPT_DIR/setup/lib/detect.sh"
# shellcheck source=setup/lib/link.sh
source "$SCRIPT_DIR/setup/lib/link.sh"
# shellcheck source=setup/lib/packages.sh
source "$SCRIPT_DIR/setup/lib/packages.sh"

usage() {
    cat <<'USAGE'
Usage:
  ./setup.sh --profile <server|local> [options]

Options:
  --profile <name>      Required: server or local
  --dry-run             Print planned changes without applying
  -y, --yes             Skip confirmation prompt
  --xdg-config-home <path>
                        Set default XDG_CONFIG_HOME written to ~/.zshenv (default: ~/.config)
  --with-<feature>      Enable a feature (starship, direnv, smartcli, r, claude)
  --without-<feature>   Disable a feature
  --skip-packages       Skip package installation phase
  --no-sudo             Never use sudo for package operations
  --backup-dir <path>   Where replaced files are moved (default: timestamped dir)
  -h, --help            Show this help

Feature defaults:
  local:  starship=1 direnv=1 smartcli=1 r=1 claude=1
  server: starship=0 direnv=0 smartcli=0 r=0 claude=0
USAGE
}

PROFILE=""
MODE="apply"
AUTO_YES=0
XDG_CONFIG_HOME_VALUE="$HOME/.config"
SKIP_PACKAGES=0
NO_SUDO=0
BACKUP_DIR=""
FEATURE_OVERRIDES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            shift 2
            ;;
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --apply)
            # Kept for backwards compat; now the default
            MODE="apply"
            shift
            ;;
        -y|--yes)
            AUTO_YES=1
            shift
            ;;
        --xdg-config-home)
            XDG_CONFIG_HOME_VALUE="${2:-}"
            shift 2
            ;;
        --with-*)
            _feat="${1#--with-}"
            FEATURE_OVERRIDES+=("${_feat^^}=1")
            unset _feat
            shift
            ;;
        --without-*)
            _feat="${1#--without-}"
            FEATURE_OVERRIDES+=("${_feat^^}=0")
            unset _feat
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=1
            shift
            ;;
        --no-sudo)
            NO_SUDO=1
            shift
            ;;
        --backup-dir)
            BACKUP_DIR="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

if [[ -z "$PROFILE" ]]; then
    usage
    die "--profile is required"
fi
if [[ "$PROFILE" != "server" && "$PROFILE" != "local" ]]; then
    die "Invalid --profile value '$PROFILE' (expected 'server' or 'local')"
fi
if [[ -z "$XDG_CONFIG_HOME_VALUE" ]]; then
    die "Invalid --xdg-config-home value (must be a non-empty path)"
fi
if [[ "$XDG_CONFIG_HOME_VALUE" != /* ]]; then
    die "--xdg-config-home must be an absolute path (got '$XDG_CONFIG_HOME_VALUE')"
fi

if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$HOME/dotfiles-backup/$(timestamp)"
fi

if [[ "$MODE" == "apply" ]]; then
    APPLY=1
else
    APPLY=0
fi

DOTFILES_DIR="$SCRIPT_DIR"
OS_ID="$(detect_os)"
PKG_MANAGER="$(detect_package_manager)"
SUDO_OK="$(detect_sudo "$NO_SUDO")"

# Build and persist profile feature flags
PROFILE_CONTENT="$(build_profile_content "$PROFILE" "${FEATURE_OVERRIDES[@]+"${FEATURE_OVERRIDES[@]}"}")"
eval "$PROFILE_CONTENT"

log_info "Dotfiles setup"
log_info "  profile      : $PROFILE"
log_info "  mode         : $MODE"
log_info "  dotfiles dir : $DOTFILES_DIR"
log_info "  xdg config   : $XDG_CONFIG_HOME_VALUE"
log_info "  os           : $OS_ID"
log_info "  pkg manager  : ${PKG_MANAGER:-none}"
log_info "  sudo         : $SUDO_OK"
log_info "  features     : starship=$DOTFILES_FEAT_STARSHIP direnv=$DOTFILES_FEAT_DIRENV smartcli=$DOTFILES_FEAT_SMARTCLI r=$DOTFILES_FEAT_R claude=$DOTFILES_FEAT_CLAUDE"
log_info "  backup dir   : $BACKUP_DIR"

if [[ "$APPLY" -eq 0 ]]; then
    log_info "Dry-run mode. Re-run without --dry-run to apply."
elif [[ "$AUTO_YES" -eq 0 ]] && [[ -t 0 ]]; then
    printf '\nProceed? [Y/n] '
    read -r answer
    if [[ "$answer" =~ ^[Nn] ]]; then
        log_info "Aborted."
        exit 0
    fi
fi

phase "Ensure base directories"
ensure_dir "$HOME/.local/bin"
ensure_dir "$HOME/.local/share"
ensure_dir "$HOME/.local/state/zsh"
ensure_dir "$HOME/.cache"
ensure_dir "$HOME/.ssh"
set_mode "$HOME/.ssh" 700
ensure_dir "$HOME/.ssh/sockets"
set_mode "$HOME/.ssh/sockets" 700

phase "Link / write managed files"
write_file_from_string "$HOME/.zshenv" "$(bootstrap_zshenv_content "$DOTFILES_DIR" "$XDG_CONFIG_HOME_VALUE" "$PROFILE")" "$BACKUP_DIR"
write_file_from_string "$HOME/.ssh/config" "Include $DOTFILES_DIR/ssh/config" "$BACKUP_DIR"
set_mode "$HOME/.ssh/config" 600
run_or_print touch "$HOME/.hushlogin"

# Python shims: force uv workflows (local profile only)
if [[ "$PROFILE" == "local" ]]; then
    _python_shim='#!/usr/bin/env sh
echo "Blocked: use '\''uv run python ...'\'' (or python3)." >&2
exit 1'
    _pip_shim='#!/usr/bin/env sh
exec uv pip "$@"'
    write_file_from_string "$HOME/.local/bin/python" "$_python_shim" "$BACKUP_DIR"
    set_mode "$HOME/.local/bin/python" 755
    write_file_from_string "$HOME/.local/bin/pip" "$_pip_shim" "$BACKUP_DIR"
    set_mode "$HOME/.local/bin/pip" 755
    run_or_print ln -sf "$HOME/.local/bin/pip" "$HOME/.local/bin/pip3"
    unset _python_shim _pip_shim
else
    log_info "Skipping python/pip shims (server profile)."
fi

ensure_dir "$XDG_CONFIG_HOME_VALUE/dotfiles"
write_file_from_string "$XDG_CONFIG_HOME_VALUE/dotfiles/profile" "$PROFILE_CONTENT" "$BACKUP_DIR"

if [[ "$DOTFILES_FEAT_R" -eq 1 ]]; then
    link_file "$DOTFILES_DIR/r/Rprofile" "$HOME/.Rprofile" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/r/Renviron" "$HOME/.Renviron" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/r/lintr" "$HOME/.lintr" "$BACKUP_DIR"
else
    log_info "Skipping R dotfiles (use --with-r to include)."
fi

if [[ "$DOTFILES_FEAT_CLAUDE" -eq 1 ]]; then
    ensure_dir "$HOME/.claude"
    ensure_dir "$HOME/.codex/rules"
    ensure_dir "$HOME/.agents"

    link_file "$DOTFILES_DIR/agents/claude/settings.json" "$HOME/.claude/settings.json" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/agents/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/agents/skills" "$HOME/.claude/skills" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/agents/skills" "$HOME/.agents/skills" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/agents/codex/config.toml" "$HOME/.codex/config.toml" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/agents/codex/rules/default.rules" "$HOME/.codex/rules/default.rules" "$BACKUP_DIR"
    link_file "$DOTFILES_DIR/agents/codex/AGENTS.md" "$HOME/.codex/AGENTS.md" "$BACKUP_DIR"
else
    log_info "Skipping agent configs (use --with-claude to include)."
fi

# macOS SSH FIDO2 support (build sk-libfido2.dylib if missing)
if [[ "$OS_ID" == "darwin" && -x "$DOTFILES_DIR/ssh/build-sk-libfido2.sh" ]]; then
    if [[ ! -f /usr/local/lib/sk-libfido2.dylib ]]; then
        log_info "Building sk-libfido2.dylib for macOS SSH FIDO2 support..."
        run_or_print "$DOTFILES_DIR/ssh/build-sk-libfido2.sh"
    else
        log_info "sk-libfido2.dylib already present."
    fi
fi

phase "Package phase"
if [[ "$SKIP_PACKAGES" -eq 1 ]]; then
    log_info "Skipping packages (--skip-packages)."
else
    install_packages \
        "$DOTFILES_DIR/setup/packages/packages.shared.txt" \
        "$DOTFILES_DIR/setup/packages/packages.$PROFILE.txt" \
        "$PKG_MANAGER" \
        "$SUDO_OK" \
        "$APPLY"
    install_feature_packages "$PKG_MANAGER" "$SUDO_OK"

    # On macOS local, install from Brewfile
    if [[ "$OS_ID" == "darwin" && "$PROFILE" == "local" && "$PKG_MANAGER" == "brew" ]]; then
        local_brewfile="$DOTFILES_DIR/macos/packages.Brewfile"
        if [[ -f "$local_brewfile" ]]; then
            log_info "Installing macOS packages from Brewfile..."
            run_or_print brew bundle --file="$local_brewfile" --no-lock
        fi
        unset local_brewfile
    fi
fi

phase "Post-setup"

# Convert dotfiles remote to SSH if currently HTTPS
if command -v git >/dev/null 2>&1 && git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _origin_url="$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ "$_origin_url" == http://* || "$_origin_url" == https://* ]]; then
        _host_and_path="${_origin_url#*://}"
        _host="${_host_and_path%%/*}"
        _repo_path="${_host_and_path#*/}"
        _ssh_url="git@${_host}:${_repo_path}"
        log_info "Converting dotfiles remote to SSH: $_ssh_url"
        run_or_print git -C "$DOTFILES_DIR" remote set-url origin "$_ssh_url"
        unset _host_and_path _host _repo_path _ssh_url
    fi
    unset _origin_url
fi

log_info "Verify: zsh -i -c 'exit'"
log_info "Verify: git config --list | head"
if [[ "$DOTFILES_FEAT_R" -eq 1 ]]; then
    log_info "Verify: R --quiet -e 'sessionInfo()'"
fi

if [[ "$APPLY" -eq 0 ]]; then
    log_info "No changes were applied (dry-run)."
else
    log_info "Bootstrap apply completed."
fi
