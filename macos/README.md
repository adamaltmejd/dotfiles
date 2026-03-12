# macOS Helpers

This directory contains optional macOS-only helpers.

## Files

- `packages.Brewfile`: Homebrew package and cask manifest.
- `apply-defaults.zsh`: applies macOS `defaults` settings.

## Usage

Run from repo root:

```zsh
# Install/upgrade packages from manifest
brew bundle --file ./macos/packages.Brewfile

# Apply macOS defaults
./macos/apply-defaults.zsh
```

Notes:

- `apply-defaults.zsh` may require logout/restart for some settings.
- `apply-defaults.zsh` uses `sudo` for one setting (`/Volumes` visibility) when needed.
