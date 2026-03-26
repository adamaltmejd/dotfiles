# Dotfiles

XDG-compliant dotfiles for macOS and Linux, with profile-aware setup.

## Install

One-liner for a fresh machine (requires `curl` and `bash`):

```bash
curl -fsSL https://raw.githubusercontent.com/adamaltmejd/dotfiles/main/setup/bootstrap.sh | bash
```

This auto-detects your OS (macOS → `local`, Linux → `server`), installs git if needed, clones the repo to `~/.config`, and runs setup.

### Options

```bash
# Explicit profile
curl -fsSL .../bootstrap.sh | bash -s -- --profile server

# Preview without applying
curl -fsSL .../bootstrap.sh | bash -s -- --dry-run

# Enable specific features on server
curl -fsSL .../bootstrap.sh | bash -s -- --with-claude --with-starship
```

### Manual setup

```bash
git clone https://github.com/adamaltmejd/dotfiles.git ~/.config
cd ~/.config
./setup/setup.sh --profile local --dry-run   # preview
./setup/setup.sh --profile local             # run (prompts for confirmation)
exec zsh
```

On macOS, install Xcode CLI tools first: `xcode-select --install`

## What it does

Setup writes a minimal `~/.zshenv` that sets XDG variables and points `ZDOTDIR` at the repo's `zsh/` directory. Everything else is either symlinked or installed from there.

### Profiles

| | `local` (macOS default) | `server` (Linux default) |
|---|---|---|
| Shell + git config | yes | yes |
| Packages | full Brewfile + shared | shared + htop + zellij |
| [Modern CLI tools](#modern-cli-tools) | yes (starship, eza, bat, fd, fzf, zoxide) | no |
| direnv | yes | no |
| R dotfiles | yes | no |
| Claude/Codex config | yes | no |
| Python/pip shims (enforce uv) | yes | no |

Override any feature with `--with-<feature>` or `--without-<feature>`.

### What setup touches

| Target | Action |
|--------|--------|
| `~/.zshenv` | Written (XDG vars + ZDOTDIR) |
| `~/.ssh/config` | Written (Include directive) |
| `~/.local/bin/python`, `pip` | Shims enforcing `uv` (local only) |
| `~/.config/setup/profile` | Feature flags for shell to read |
| `~/.Rprofile`, `~/.Renviron`, etc. | Symlinked (if R enabled) |
| `~/.claude/`, `~/.codex/`, `~/.agents/` | Symlinked from `agents/` (if claude enabled) |

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

Managed via 1Password CLI (`op`) and direnv. Templates in `zsh/secrets/` contain `op://` references. A custom `use_op` direnv function (defined in `direnv/direnvrc`) resolves references via `op inject`, caches the result, and exports as env vars.

Usage in any `.envrc`:
```bash
use op ~/.config/zsh/secrets/base.env        # global secrets
use op .secrets.env.tpl                       # project-specific (optional)
dotenv_if_exists .secrets.env                 # plaintext overrides (optional)
```

On servers without `op`/direnv: use `zsh/secrets/local.zsh` (plaintext, gitignored).

## Repository layout

```
dotfiles/
├── setup/
│   ├── bootstrap.sh        # curl-to-bash entry point
│   ├── setup.sh            # main setup script
│   ├── lib/                # detection, linking, package helpers
│   ├── macos-defaults.zsh  # macOS system defaults
│   └── packages/           # package manifests (shared, local, server, Brewfile)
├── zsh/                    # ZDOTDIR — .zshrc, .zshenv, conf.d/
├── direnv/                 # direnvrc with use_op helper
├── git/                    # git config
├── ssh/                    # ssh config + config.d/ for hosts
├── r/                      # Rprofile, Renviron, Makevars, lintr
├── radian/                 # radian console config
├── zellij/                 # zellij multiplexer config (server use)
├── agents/                 # AI agent configs + shared skills
│   ├── claude/             # Claude Code settings
│   ├── codex/              # Codex CLI config + rules
│   └── skills/             # shared skills (symlinked to ~/.claude/skills)
├── ansible/                # ansible config
├── gh/                     # GitHub CLI config
└── ghostty/                # ghostty terminal config
```

## License

MIT
