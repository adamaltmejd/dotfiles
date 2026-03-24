# Dotfiles

XDG-compliant dotfiles for macOS and Linux, with profile-aware bootstrap.

## Install

One-liner for a fresh machine (requires `curl` and `bash`):

```bash
curl -fsSL https://raw.githubusercontent.com/adamaltmejd/dotfiles/main/install.sh | bash
```

This auto-detects your OS (macOS → `local`, Linux → `server`), installs git if needed, clones the repo to `~/.config/dotfiles`, and runs bootstrap with `--apply`.

### Options

```bash
# Explicit profile
curl -fsSL .../install.sh | bash -s -- --profile server

# Preview without applying
curl -fsSL .../install.sh | bash -s -- --dry-run

# Enable specific features on server
curl -fsSL .../install.sh | bash -s -- --with-claude --with-starship

# Custom clone location
curl -fsSL .../install.sh | bash -s -- --dotfiles-dir ~/dotfiles
```

### Manual setup

```bash
git clone https://github.com/adamaltmejd/dotfiles.git ~/.config/dotfiles
cd ~/.config/dotfiles
./bootstrap.sh --profile local --dry-run   # preview
./bootstrap.sh --profile local --apply     # run
exec zsh
```

On macOS, install Xcode CLI tools first: `xcode-select --install`

## What it does

Bootstrap writes a minimal `~/.zshenv` that sets XDG variables and points `ZDOTDIR` at the repo's `zsh/` directory. Everything else is either symlinked or installed from there.

### Profiles

| | `local` (macOS default) | `server` (Linux default) |
|---|---|---|
| Shell + git config | yes | yes |
| Packages | full Brewfile + shared | shared + htop |
| [Modern CLI tools](#modern-cli-tools) | yes (starship, eza, bat, fd, fzf, zoxide) | no |
| direnv | yes | no |
| R dotfiles | yes | no |
| Claude/Codex config | yes | no |
| Python/pip shims (enforce uv) | yes | no |

Override any feature with `--with-<feature>` or `--without-<feature>`.

### What bootstrap touches

| Target | Action |
|--------|--------|
| `~/.zshenv` | Written (XDG vars + ZDOTDIR) |
| `~/.ssh/config` | Written (Include directive) |
| `~/.local/bin/python`, `pip` | Shims enforcing `uv` (local only) |
| `~/.config/dotfiles/profile` | Feature flags for shell to read |
| `~/.Rprofile`, `~/.Renviron`, etc. | Symlinked (if R enabled) |
| `~/.claude/`, `~/.codex/` | Symlinked (if claude enabled) |

Existing files are backed up to `~/dotfiles-backup/<timestamp>/` before replacement.

## Modern CLI tools

Installed on `local` profile (or with `--with-smartcli`):

| Tool | Replaces | Usage |
|------|----------|-------|
| `eza` | `ls` | Aliased to `ls`, `l`, `la`, `tree` |
| `bat` | `cat` | Aliased to `cat`, also used as man pager |
| `ripgrep` | `grep` | `rg` |
| `fd` | `find` | `fd` |
| `zoxide` | `cd` | `z <partial>` |
| `fzf` | — | Ctrl+R history, Ctrl+T files |
| `starship` | prompt | Cross-shell prompt |
| `delta` | git diff | Automatic via gitconfig |

## Secrets

Managed via 1Password CLI (`op`). No secrets are stored in this repository. Loaded at shell startup via `zsh/secrets.zsh`.

## Repository layout

```
dotfiles/
├── install.sh              # curl-to-bash installer
├── bootstrap.sh            # main setup entrypoint
├── bootstrap/
│   ├── lib/                # detection, linking, package helpers
│   └── packages/           # package manifests (shared, local, server)
├── zsh/                    # ZDOTDIR — .zshrc, .zshenv, conf.d/
├── git/                    # git config
├── ssh/                    # ssh config + config.d/ for hosts
├── macos/                  # Brewfile, apply-defaults.zsh
├── r/                      # Rprofile, Renviron, Makevars, lintr
├── radian/                 # radian console config
├── claude/                 # Claude Code settings
├── codex/                  # Codex CLI config + rules
├── ansible/                # ansible config
├── gh/                     # GitHub CLI config
└── ghostty/                # ghostty terminal config
```

## License

MIT
