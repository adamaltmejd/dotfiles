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

if [[ ! -f "$HOME/.ssh/config" ]]; then
    # Fresh install - create config with Include
    cat > "$HOME/.ssh/config" << 'EOF'
# Include dotfiles SSH config
Include ~/.config/ssh/config
Include ~/.config/ssh/config.d/*
EOF
elif ! grep -q "Include.*\.config/ssh/config" "$HOME/.ssh/config"; then
    # Existing config - prepend Include if not already present
    echo "Adding Include directive to existing ~/.ssh/config..."
    temp=$(mktemp)
    echo "# Include dotfiles SSH config" > "$temp"
    echo "Include ~/.config/ssh/config" >> "$temp"
    echo "Include ~/.config/ssh/config.d/*" >> "$temp"
    echo "" >> "$temp"
    cat "$HOME/.ssh/config" >> "$temp"
    mv "$temp" "$HOME/.ssh/config"
fi
chmod 600 "$HOME/.ssh/config"

# Suppress login message
touch "$HOME/.hushlogin"

echo "Setup complete. Restart your shell with: exec zsh"
