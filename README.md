# Dotfiles

XDG-compliant dotfiles for macOS. This repository is designed to be cloned directly to `~/.config`.

## Quick Start

```zsh
# 1. Install Xcode CLI tools
xcode-select --install

# 2. Clone directly to ~/.config
git clone https://github.com/adamaltmejd/dotfiles.git ~/.config

# 3. Run setup
~/.config/system/setup.sh

# 4. Restart shell
exec zsh
```

## Structure

```
~/.config/                      # This repo
├── zsh/                        # ZDOTDIR - all zsh config
│   ├── .zshrc
│   ├── .zshenv
│   ├── .p10k.zsh
│   ├── plugins.txt             # Antidote plugins
│   ├── secrets.zsh             # 1Password secrets loader
│   └── conf.d/                 # Topic-based configs
│       ├── core.zsh
│       ├── git.zsh
│       ├── macos.zsh
│       ├── node.zsh
│       ├── python.zsh
│       └── r.zsh
├── git/                        # Git config (XDG native)
│   ├── config
│   └── ignore
├── r/                          # R configs (symlinked to ~/)
│   ├── Rprofile
│   ├── Renviron
│   ├── Makevars
│   └── lintr
├── radian/                     # Radian R console config
│   └── profile
├── ssh/                        # SSH config (included by ~/.ssh/config)
│   ├── config
│   └── config.d/
├── ansible/                    # Ansible config
│   └── vault-password-file
└── system/                     # Setup scripts, Brewfile
    ├── setup.sh
    └── Brewfile
```

## XDG Base Directory

This setup uses the XDG Base Directory Specification:

| Variable | Location | Purpose |
|----------|----------|---------|
| `XDG_CONFIG_HOME` | `~/.config` | User config files (this repo) |
| `XDG_DATA_HOME` | `~/.local/share` | User data files |
| `XDG_STATE_HOME` | `~/.local/state` | User state (logs, history) |
| `XDG_CACHE_HOME` | `~/.cache` | Non-essential cached data |

## Files Outside ~/.config

Some tools don't support XDG. These are handled by `setup.sh`:

| File | Purpose | How |
|------|---------|-----|
| `~/.zshenv` | Bootstrap ZDOTDIR | Written by setup.sh |
| `~/.ssh/config` | SSH configuration | Includes `~/.config/ssh/config` |
| `~/.Rprofile` | R startup | Symlink to `r/Rprofile` |
| `~/.Renviron` | R environment | Symlink to `r/Renviron` |

## Modern CLI Tools

| Tool | Replaces | Usage |
|------|----------|-------|
| `eza` | `ls` | Aliased to `ls`, `l`, `la`, `tree` |
| `bat` | `cat` | Aliased to `cat`, also used as man pager |
| `ripgrep` | `grep` | `rg` |
| `fd` | `find` | `fd` |
| `zoxide` | `cd` | `z <partial>` |
| `fzf` | - | Ctrl+R history, Ctrl+T files |
| `tlrc` | `man`/`tldr` | Modern tldr client |
| `delta` | git diff | Automatic via gitconfig |

## Package Managers

| Language | Tool | Notes |
|----------|------|-------|
| Python | `uv` | Fast pip/venv replacement |
| JavaScript | `bun` | Fast npm/node replacement |
| R | `renv` + `pak` | Per-project isolation |

## Secrets

Secrets are managed via 1Password CLI (`op`). No secrets are stored in this repository. Secrets are loaded via `zsh/secrets.zsh`.

## License

MIT
