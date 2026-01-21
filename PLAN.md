# Dotfiles Reorganization Plan

## Overview

Migrate from Dropbox-synced dotfiles to a git-based XDG-compliant structure where `~/.config` **is** the repository.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Repo location | `~/.config` is the repo itself |
| Bootstrap | `~/.zshenv` written by setup.sh (not symlinked) |
| Multi-machine | Local overrides initially; branches if needed later |
| Secrets | 1Password CLI (`op read`) |
| Shell organization | By topic (git.zsh, python.zsh, r.zsh, etc.) |
| App configs | Track customized ones; ignore auto-generated |
| Non-XDG files | Separate standard locations, configured by setup.sh |

---

## Phase 1: Directory Structure

### Repository root: `~/.config/`

```
~/.config/                      # THE REPO
├── .gitignore                  # Whitelist approach for ~/.config
├── README.md
├── CLAUDE.md
│
├── zsh/                        # ZDOTDIR
│   ├── .zshrc
│   ├── .zshenv                 # Sourced by bootstrap ~/.zshenv
│   ├── .zlogin
│   ├── .zlogout
│   ├── .zprofile
│   ├── .p10k.zsh
│   ├── plugins.txt             # Antidote plugin list
│   └── conf.d/                 # Topic-based shell configs
│       ├── core.zsh            # Base shell options, completions
│       ├── git.zsh             # Git aliases, functions
│       ├── python.zsh          # Python/uv config
│       ├── r.zsh               # R/renv config
│       ├── node.zsh            # Bun/node config
│       ├── macos.zsh           # macOS-specific (clipboard, open, etc.)
│       ├── ssh.zsh             # SSH agent, keys
│       └── local.zsh           # Machine-specific (gitignored)
│
├── git/
│   ├── config                  # Main gitconfig (XDG native)
│   ├── ignore                  # Global gitignore
│   └── config.local            # Machine-specific (gitignored)
│
├── r/
│   ├── Rprofile                # Symlinked to ~/.Rprofile by setup
│   ├── Renviron                # Symlinked to ~/.Renviron by setup
│   ├── lintr
│   └── Makevars
│
├── ssh/                        # SSH config templates
│   ├── config                  # Main config, Include'd by ~/.ssh/config
│   └── config.d/               # Host-specific configs
│
├── pandoc/
│   └── ...
│
├── bat/                        # If customized
├── ripgrep/                    # If customized
│
├── system/                     # OS-level configs
│   ├── Brewfile
│   ├── macos-defaults.sh       # defaults write commands
│   └── setup.sh                # Main setup script
│
└── local/                      # Gitignored, machine-specific
    ├── bin/                    # Personal scripts (symlinked to ~/.local/bin)
    └── secrets.env             # Any local env vars (gitignored)
```

### Files outside `~/.config/` (managed by setup.sh)

| Location | Purpose | Setup action |
|----------|---------|--------------|
| `~/.zshenv` | Bootstrap ZDOTDIR | Written by setup.sh |
| `~/.ssh/config` | SSH config | Written with `Include ~/.config/ssh/config` |
| `~/.Rprofile` | R startup | Symlink to `~/.config/r/Rprofile` |
| `~/.Renviron` | R environment | Symlink to `~/.config/r/Renviron` |
| `~/.local/bin/` | Personal scripts | Symlink or copy from repo |
| `~/.hushlogin` | Suppress login message | Written by setup.sh |
| `~/.latexmkrc` | LaTeX config | Symlink to `~/.config/latexmk/latexmkrc` |

---

## Phase 2: Server Dotfiles Integration (Future)

Integrate minimal server dotfiles into same repo:

```
~/.config/
└── profiles/
    ├── full/           # Current macOS setup (default)
    └── server/         # Minimal zsh for remote servers
        ├── .zshrc
        └── conf.d/
```

Setup script would accept a `--profile=server` flag for minimal installation.

---

## Phase 3: Migration Steps

### 3.1 Preparation

1. Create new repo structure in `dotfiles/` directory
2. Reorganize shell configs by topic
3. Move git config to XDG location
4. Test new structure works before committing
5. Set up `.gitignore` with whitelist approach

### 3.2 Bootstrap file: `~/.zshenv`

```zsh
# ~/.zshenv - Written by setup.sh, do not edit
# Bootstrap XDG and ZDOTDIR for zsh

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
```

### 3.3 Setup script: `system/setup.sh`

```zsh
#!/bin/zsh
set -e

CONFIG_DIR="$HOME/.config"
SCRIPT_DIR="${0:A:h}"

# Ensure XDG directories exist
mkdir -p "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/state" "$HOME/.cache"

# Write bootstrap ~/.zshenv
cat > "$HOME/.zshenv" << 'EOF'
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
EOF

# SSH config with Include
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [[ ! -f "$HOME/.ssh/config" ]] || ! grep -q "Include" "$HOME/.ssh/config"; then
    echo "Include $CONFIG_DIR/ssh/config" >> "$HOME/.ssh/config"
fi

# R symlinks (R doesn't support XDG)
ln -sf "$CONFIG_DIR/r/Rprofile" "$HOME/.Rprofile"
ln -sf "$CONFIG_DIR/r/Renviron" "$HOME/.Renviron"

# LaTeX
ln -sf "$CONFIG_DIR/latexmk/latexmkrc" "$HOME/.latexmkrc"

# Hushlogin
touch "$HOME/.hushlogin"

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install packages
brew bundle --file="$SCRIPT_DIR/Brewfile"

# macOS defaults
[[ -f "$SCRIPT_DIR/macos-defaults.sh" ]] && source "$SCRIPT_DIR/macos-defaults.sh"

echo "Setup complete. Restart your shell."
```

### 3.4 Gitignore strategy (whitelist)

```gitignore
# Ignore everything by default
*

# Track these directories
!.gitignore
!README.md
!CLAUDE.md
!PLAN.md

!zsh/
!zsh/**
!git/
!git/**
!r/
!r/**
!ssh/
!ssh/**
!system/
!system/**
!pandoc/
!pandoc/**
!latexmk/
!latexmk/**

# Ignore local overrides within tracked dirs
zsh/conf.d/local.zsh
git/config.local
local/

# Common junk
.DS_Store
*.swp
*~
```

---

## Phase 4: New Machine Setup

```zsh
# 1. Install Xcode CLI tools
xcode-select --install

# 2. Clone dotfiles directly to ~/.config
git clone https://github.com/adamaltmejd/dotfiles.git ~/.config

# 3. Run setup
~/.config/system/setup.sh

# 4. Restart shell
exec zsh
```

---

## Secrets Strategy (1Password CLI)

For secrets that shouldn't be in the repo:

```zsh
# In conf.d/secrets.zsh (tracked, but references op)
export GITHUB_TOKEN="$(op read 'op://Personal/GitHub Token/token')"
export OPENAI_API_KEY="$(op read 'op://Personal/OpenAI/api_key')"
```

Or use `op inject` for config files:

```zsh
op inject -i ~/.config/some-template.tpl -o ~/.config/some-config.actual
```

**Note:** Evaluate if `op` startup latency is acceptable. Fallback: encrypted `.env` file decrypted on setup.

---

## Migration Checklist

- [x] Create new repo with README.md, CLAUDE.md, PLAN.md
- [x] Create directory structure (zsh/, git/, ssh/, r/, radian/, system/)
- [x] Write .gitignore (whitelist approach)
- [x] Write system/setup.sh (bootstrap, SSH, R symlinks, Homebrew)
- [x] Migrate zsh essentials (core.zsh with options, completions, keybinds, core aliases)
- [x] Migrate zsh topic configs (git.zsh, python.zsh, r.zsh, macos.zsh, node.zsh)
- [x] Migrate git config to `git/config` (modernized)
- [x] Migrate SSH configs to `ssh/`
- [x] Migrate R configs to `r/` and `radian/`
- [x] Add Homebrew Brewfile to `system/`
- [x] Test on current machine with new ZDOTDIR
- [x] Push to GitHub
- [ ] Set up secrets with 1Password CLI
- [ ] Test fresh install on VM or second machine
- [ ] Remove Dropbox sync

---

## Open Questions

1. **LaTeX config** - Does `.latexmkrc` need to stay in `$HOME` or can latexmk read from elsewhere?
2. **radian_profile** - Does radian support XDG or need symlink?
3. **GPG config** - Move to `~/.config/gnupg/` (needs `GNUPGHOME` set) or keep `~/.gnupg/`?

---

## Files to Migrate

| Current location | New location |
|-----------------|--------------|
| `.zshrc` | `zsh/.zshrc` |
| `.zshenv` | `zsh/.zshenv` |
| `.zprofile`, `.zlogin`, `.zlogout` | `zsh/` |
| `.p10k.zsh` | `zsh/.p10k.zsh` |
| `.zsh_plugins.txt` | `zsh/plugins.txt` |
| `.gitconfig` | `git/config` |
| `.adamaltmejd/gitignore_global` | `git/ignore` |
| `.adamaltmejd/aliases` | Split into `zsh/conf.d/*.zsh` |
| `.adamaltmejd/functions` | Split into `zsh/conf.d/*.zsh` |
| `.adamaltmejd/exports` | Split into `zsh/conf.d/*.zsh` |
| `.adamaltmejd/path` | `zsh/.zshenv` |
| `.adamaltmejd/key_bindings` | `zsh/conf.d/core.zsh` |
| `.adamaltmejd/term-config` | `zsh/conf.d/core.zsh` |
| `.adamaltmejd/ssh/*` | `ssh/` |
| `.adamaltmejd/R/*` | `r/` |
| `.adamaltmejd/bin/*` | `local/bin/` or tracked if universal |
| `.adamaltmejd/pandoc/*` | `pandoc/` |
| `.Rprofile` | `r/Rprofile` |
| `.Renviron` | `r/Renviron` |
| `.lintr` | `r/lintr` |
| `.latexmkrc` | `latexmk/latexmkrc` |
| `.radian_profile` | `radian/profile` |
| `Brewfile` | `system/Brewfile` |
| `setup.sh` | `system/setup.sh` |
