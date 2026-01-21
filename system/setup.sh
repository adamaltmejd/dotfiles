#!/usr/bin/env zsh
# Dotfiles setup script
# Run this after cloning the repo to ~/.config
set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="${0:A:h}"

echo "Setting up dotfiles..."

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install packages from Brewfile
echo "Installing Homebrew packages..."
brew bundle --file="$SCRIPT_DIR/Brewfile"
brew cleanup

echo ""
echo "Log in to installed services (1Password, etc.) before continuing."
echo "Press Enter when ready..."
read

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
if [[ -d "$HOME/.ssh" ]]; then
    mv "$HOME/.ssh" "$HOME/ssh-debug"
    echo "Moved existing ~/.ssh to ~/ssh-debug"
fi
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh"
cat > "$HOME/.ssh/config" << 'EOF'
Include ~/.config/ssh/config
EOF
chmod 600 "$HOME/.ssh/config"

# Inject SSH config from 1Password
if command -v op &>/dev/null; then
    echo "Injecting SSH config from 1Password..."
    op read "op://Work/ir2amtuqlhxc6oyaxhgwiixum4/ssh config" --out-file "$CONFIG_DIR/ssh/config.d/SOFI.local"
    chmod 600 "$CONFIG_DIR/ssh/config.d/SOFI.local"
fi

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

echo "Setup complete. Restart your shell with: exec zsh"
