# Dotfiles

XDG-compliant dotfiles for macOS and Linux. The default `XDG_CONFIG_HOME` is `~/.config`, but custom paths are supported.

## Quick Start

```zsh
# 1. Install Xcode CLI tools (macOS)
xcode-select --install

# 2. Clone (default path)
git clone https://github.com/adamaltmejd/dotfiles.git ~/.config

# 3. Preview then apply (local profile)
~/.config/bootstrap.sh --profile local --dry-run
~/.config/bootstrap.sh --profile local --apply

# 4. Restart shell
exec zsh
```

## Setup Entry Point

`bootstrap.sh` is the only supported setup entrypoint.

```zsh
# Server
./bootstrap.sh --profile server --dry-run
./bootstrap.sh --profile server --apply

# Local
./bootstrap.sh --profile local --dry-run
./bootstrap.sh --profile local --apply
```

## Profiles

- `local`: desktop/laptop defaults, includes `claude/` and `codex/`, includes R dotfiles by default.
- `server`: broadly useful server defaults, lighter shell footprint, skips R dotfiles by default.

## Custom XDG_CONFIG_HOME

Use `--xdg-config-home` if your repo is not at `~/.config`.

```zsh
/path/to/dotfiles/bootstrap.sh --profile local --xdg-config-home /path/to/dotfiles --dry-run
/path/to/dotfiles/bootstrap.sh --profile local --xdg-config-home /path/to/dotfiles --apply
```

## Repository Layout

```text
dotfiles/
├── bootstrap.sh                # setup entrypoint
├── bootstrap/                  # bootstrap internals
│   ├── lib/                    # detection/linking/package helpers
│   └── packages/               # package manifests by profile
├── zsh/                        # ZDOTDIR
├── git/                        # git config
├── ssh/                        # ssh config
├── r/                          # R config sources
├── radian/                     # radian config
├── ansible/                    # ansible config
├── gh/                         # GitHub CLI config
├── ghostty/                    # ghostty config
├── claude/                     # local-profile managed
├── codex/                      # local-profile managed
├── macos/                      # macOS helpers (apply-defaults.zsh, packages.Brewfile)
├── docs/                       # local/server notes
└── legacy/                     # migration snapshot (not active runtime config)
```

## XDG Base Directory

| Variable | Location | Purpose |
|----------|----------|---------|
| `XDG_CONFIG_HOME` | `~/.config` | User config files (this repo) |
| `XDG_DATA_HOME` | `~/.local/share` | User data files |
| `XDG_STATE_HOME` | `~/.local/state` | User state (logs, history) |
| `XDG_CACHE_HOME` | `~/.cache` | Non-essential cached data |

## Files Outside XDG Config

Some tools do not support XDG config paths. These are managed by `bootstrap.sh`:

| File | Purpose | How |
|------|---------|-----|
| `~/.zshenv` | Bootstrap ZDOTDIR + XDG vars | Written by bootstrap.sh |
| `~/.ssh/config` | SSH include entrypoint | Includes `$DOTFILES_DIR/ssh/config` |
| `~/.Rprofile` | R startup | Symlink to `r/Rprofile` |
| `~/.Renviron` | R environment | Symlink to `r/Renviron` |

Server profile note: R dotfiles are skipped by default on `--profile server`; use `--with-r` to opt in.

## macOS Helpers

```zsh
# Install macOS packages and casks
brew bundle --file ./macos/packages.Brewfile

# Apply macOS defaults
./macos/apply-defaults.zsh
```

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
