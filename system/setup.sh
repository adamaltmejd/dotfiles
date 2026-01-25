#!/usr/bin/env zsh
# Dotfiles setup script
# Run this after cloning the repo to ~/.config
set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="${0:A:h}"
BACKUP_DIR="$HOME/dotfiles-setup-backup-$(date +%Y%m%d-%H%M%S)"

# Write file, backing up existing if different
# Usage: write_with_backup target < content  OR  write_with_backup target << 'EOF'
write_with_backup() {
    local target="$1"
    local new_content="$(cat)"
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ ! -f "$target" || "$(cat "$target")" != "$new_content" ]]; then
            mkdir -p "$BACKUP_DIR"
            mv "$target" "$BACKUP_DIR/"
            echo "Backed up $target to $BACKUP_DIR/"
        fi
    fi
    printf '%s' "$new_content" > "$target"
}

echo "Setting up dotfiles..."

# Ensure git remote uses SSH
if command -v git &>/dev/null; then
    if git -C "$CONFIG_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        origin_url="$(git -C "$CONFIG_DIR" remote get-url origin 2>/dev/null || true)"
        if [[ "$origin_url" == http://* || "$origin_url" == https://* ]]; then
            host_and_path="${origin_url#*://}"
            host="${host_and_path%%/*}"
            repo_path="${host_and_path#*/}"
            ssh_url="git@${host}:${repo_path}"
            echo "Updating git remote origin to SSH: $ssh_url"
            git -C "$CONFIG_DIR" remote set-url origin "$ssh_url"
        fi
    fi
fi

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install packages from Brewfile
echo "Installing Homebrew packages..."
brew update && brew upgrade
brew bundle --file="$SCRIPT_DIR/Brewfile"
brew cleanup

# Create XDG directories
echo "Creating XDG directories..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share"
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache"

# Write bootstrap ~/.zshenv
echo "Writing bootstrap ~/.zshenv..."
write_with_backup "$HOME/.zshenv" << 'EOF'
#!/usr/bin/env zsh
# Bootstrap XDG and ZDOTDIR - written by ~/.config/system/setup.sh
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
EOF

# SSH configuration
echo "Setting up SSH..."
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh"
write_with_backup "$HOME/.ssh/config" << 'EOF'
Include ~/.config/ssh/config
EOF
chmod 600 "$HOME/.ssh/config"

# Build sk-libfido2.dylib for macOS built-in SSH FIDO2 support
[[ -f /usr/local/lib/sk-libfido2.dylib ]] || "$CONFIG_DIR/ssh/build-sk-libfido2.sh"

# R configuration (R doesn't support XDG, needs symlinks)
echo "Setting up R..."
mkdir -p "$HOME/.R"
ln -sf "$CONFIG_DIR/r/Rprofile" "$HOME/.Rprofile"
ln -sf "$CONFIG_DIR/r/Renviron" "$HOME/.Renviron"
ln -sf "$CONFIG_DIR/r/lintr" "$HOME/.lintr"
ln -sf "$CONFIG_DIR/r/Makevars" "$HOME/.R/Makevars"
# Note: radian uses XDG natively ($XDG_CONFIG_HOME/radian/profile)

# Suppress login message
touch "$HOME/.hushlogin"

# Check for 1Password CLI and inject SSH config
if ! command -v op &>/dev/null; then
    echo ""
    echo "Log in to 1Password and enable the CLI integration before continuing."
    echo "Press Enter when ready..."
    read
    if ! command -v op &>/dev/null; then
        echo "Warning: 1Password CLI (op) not found. Skipping SSH config injection."
        echo "Run 'op read \"op://Work/ir2amtuqlhxc6oyaxhgwiixum4/ssh config\" --out-file \"$CONFIG_DIR/ssh/config.d/SOFI.local\"' manually after setting up 1Password."
    fi
fi

if command -v op &>/dev/null; then
    echo "Injecting SSH config from 1Password..."
    op read "op://Work/ir2amtuqlhxc6oyaxhgwiixum4/ssh config" --out-file "$CONFIG_DIR/ssh/config.d/SOFI.local"
    chmod 600 "$CONFIG_DIR/ssh/config.d/SOFI.local"
fi

echo "Setup complete. Restarting shell..."
exec zsh
