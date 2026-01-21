#!/usr/bin/env zsh
# Dotfiles setup script
# Run this after cloning the repo to ~/.config
set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="${0:A:h}"

echo "Setting up dotfiles..."

# Create XDG directories
echo "Creating XDG directories..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share"
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache"

# Write bootstrap ~/.zshenv
echo "Writing bootstrap ~/.zshenv..."
cat > "$HOME/.zshenv" << 'EOF'
# Bootstrap XDG and ZDOTDIR - written by setup.sh
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
EOF

# Suppress login message
touch "$HOME/.hushlogin"

echo "Setup complete. Restart your shell with: exec zsh"
