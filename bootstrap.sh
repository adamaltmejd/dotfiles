#!/usr/bin/env bash
# Curl-to-bash bootstrap for dotfiles.
# Usage: curl -fsSL https://raw.githubusercontent.com/adamaltmejd/dotfiles/main/bootstrap.sh | bash
#   With options: ... | bash -s -- --profile server --with-claude
set -euo pipefail

REPO_URL="https://github.com/adamaltmejd/dotfiles.git"
DOTFILES_TARGET="${DOTFILES_DIR:-$HOME/.config}"
BRANCH="${DOTFILES_BRANCH:-main}"

log()  { printf '[bootstrap] %s\n' "$*"; }
die()  { printf '[error] %s\n' "$*" >&2; exit 1; }

# --- Detect OS and default profile ---

detect_profile() {
    case "$(uname -s)" in
        Darwin) echo "local" ;;
        Linux)  echo "server" ;;
        *)      die "Unsupported OS: $(uname -s)" ;;
    esac
}

# --- Ensure git is available ---

as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        die "Need root to run: $*"
    fi
}

ensure_git() {
    command -v git >/dev/null 2>&1 && return 0

    log "git not found — installing..."

    if command -v apt-get >/dev/null 2>&1; then
        as_root apt-get update -qq && as_root apt-get install -y -qq git
    elif command -v dnf >/dev/null 2>&1; then
        as_root dnf install -y git
    elif command -v yum >/dev/null 2>&1; then
        as_root yum install -y git
    elif command -v pacman >/dev/null 2>&1; then
        as_root pacman -S --noconfirm git
    elif command -v apk >/dev/null 2>&1; then
        as_root apk add git
    else
        die "Cannot install git — no supported package manager found. Install git manually and re-run."
    fi

    command -v git >/dev/null 2>&1 || die "git installation failed"
}

# --- Parse args (extract --profile if given, pass everything through) ---

PROFILE=""
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            shift 2
            ;;
        --branch)
            BRANCH="${2:-}"
            shift 2
            ;;
        *)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$PROFILE" ]]; then
    PROFILE="$(detect_profile)"
    log "Auto-detected profile: $PROFILE"
fi

# Build final args: --yes skips confirmation (stdin isn't a tty in a pipe)
SETUP_ARGS=("--profile" "$PROFILE" "--yes" "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}")

# --- Clone or update repo ---

ensure_git

if [[ -d "$DOTFILES_TARGET/.git" ]]; then
    log "Dotfiles repo already exists at $DOTFILES_TARGET — pulling latest..."
    git -C "$DOTFILES_TARGET" fetch origin
    git -C "$DOTFILES_TARGET" checkout "$BRANCH"
    git -C "$DOTFILES_TARGET" pull --ff-only origin "$BRANCH"
elif [[ -d "$DOTFILES_TARGET" ]]; then
    log "$DOTFILES_TARGET exists — initializing repo in place..."
    git -C "$DOTFILES_TARGET" init
    git -C "$DOTFILES_TARGET" remote add origin "$REPO_URL"
    git -C "$DOTFILES_TARGET" fetch origin
    git -C "$DOTFILES_TARGET" checkout -b "$BRANCH" "origin/$BRANCH"
else
    log "Cloning dotfiles to $DOTFILES_TARGET..."
    mkdir -p "$(dirname "$DOTFILES_TARGET")"
    git clone --branch "$BRANCH" "$REPO_URL" "$DOTFILES_TARGET"
fi

[[ -x "$DOTFILES_TARGET/setup.sh" ]] || die "setup.sh not found in $DOTFILES_TARGET — clone may have failed"

# --- Run setup ---

log "Running setup..."
exec "$DOTFILES_TARGET/setup.sh" "${SETUP_ARGS[@]}"
