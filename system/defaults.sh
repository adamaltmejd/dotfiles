#!/usr/bin/env zsh
# macOS system defaults
# Run via setup.sh or manually: ./defaults.sh
# Some settings require logout/restart to take effect

set -e

echo "Configuring macOS defaults..."

# Close System Preferences to prevent conflicts
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Disable automatic capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart dashes
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

###############################################################################
# Keyboard                                                                    #
###############################################################################

# Keyboard repeat rate (lower = faster, 2 is fast)
defaults write NSGlobalDomain KeyRepeat -int 12
defaults write NSGlobalDomain InitialKeyRepeat -int 68

# Full keyboard access: 2 = text boxes and lists, 3 = all controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

###############################################################################
# Trackpad & Mouse                                                            #
###############################################################################

# Enable tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Disable natural scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

###############################################################################
# Finder                                                                      #
###############################################################################

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Search scope: SCcf = current folder, SCev = entire volume, SCsp = previous scope
defaults write com.apple.finder FXDefaultSearchScope -string "SCev"

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view by default (Nlsv = list, icnv = icon, clmv = column, glyv = gallery)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the ~/Library folder
chflags nohidden ~/Library 2>/dev/null || true

# Show the /Volumes folder
sudo chflags nohidden /Volumes 2>/dev/null || true

###############################################################################
# Dock                                                                        #
###############################################################################

# Dock position: left, bottom, right
defaults write com.apple.dock orientation -string "right"

# Dock icon size
defaults write com.apple.dock tilesize -int 41

# Dock magnification (disabled)
defaults write com.apple.dock largesize -int 128

# Minimize windows using scale effect
defaults write com.apple.dock mineffect -string "scale"

# Don't show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool true

# Remove auto-hide delay
defaults write com.apple.dock autohide-delay -float 0

# Instant auto-hide animation
defaults write com.apple.dock autohide-time-modifier -float 0

###############################################################################
# Restart affected applications                                               #
###############################################################################

echo "Restarting affected applications..."
for app in "Finder" "Dock" "SystemUIServer"; do
    killall "$app" &>/dev/null || true
done

echo "macOS defaults configured. Some changes require logout/restart."
