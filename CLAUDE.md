# Claude Code Instructions

XDG-compliant macOS dotfiles. Default location is `~/.config` (`XDG_CONFIG_HOME`), with custom paths supported.

## Structure

- `zsh/` - ZDOTDIR, all zsh configuration
- `zsh/conf.d/` - Topic-based shell configs (core.zsh, git.zsh, macos.zsh, node.zsh, python.zsh, r.zsh, ssh.zsh)
- `git/` - Git config (XDG native location)
- `r/` - R configs (Rprofile, Renviron, lintr; symlinked to ~/)
- `radian/` - Radian R console config
- `ssh/` - SSH config (included by ~/.ssh/config), with config.d/ for host-specific configs
- `ansible/` - Ansible config (vault password file)
- `agents/` - AI agent configs (Claude Code, Codex CLI, shared skills)
- `agents/claude/` - Claude Code settings (symlinked to ~/.claude/)
- `agents/codex/` - Codex CLI config and rules (symlinked to ~/.codex/)
- `agents/skills/` - Shared skills (symlinked to ~/.claude/skills and ~/.agents/skills)
- `macos/` - packages.Brewfile, apply-defaults.zsh
- `bootstrap.sh` - curl-to-bash entry point (clones repo, runs setup)
- `setup.sh` - profile-aware setup script
- `setup/lib/` - setup helper modules (detect/link/packages/common)
- `setup/packages/` - profile-scoped package manifests
- `docs/` - migration notes for local/server profiles

## Key Files

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Curl-to-bash entry point for fresh machines |
| `setup.sh` | Main setup script (profiles, features, packages) |
| `macos/packages.Brewfile` | Homebrew packages and casks |
| `macos/apply-defaults.zsh` | Apply macOS defaults |
| `setup/packages/packages.shared.txt` | Shared package manifest |
| `setup/packages/packages.local.txt` | Local profile package manifest |
| `setup/packages/packages.server.txt` | Server profile package manifest |
| `zsh/.zshrc` | Interactive shell config |
| `zsh/.zshenv` | Environment variables (sourced by setup) |
| `zsh/secrets.zsh` | 1Password secrets loader |
| `zsh/conf.d/*.zsh` | Topic-specific shell configuration |
| `git/config` | Git configuration |
| `agents/claude/settings.json` | Claude Code plugins and settings |
| `agents/codex/config.toml` | Codex CLI model and feature settings |
| `agents/codex/rules/default.rules` | Codex command approval rules |

## Setup

A minimal `~/.zshenv` (written by setup.sh) sets XDG vars and ZDOTDIR, then sources `"$DOTFILES_DIR/zsh/.zshenv"`.
`zsh/.zshrc` then loads `"$XDG_CONFIG_HOME/dotfiles/host.local"` last when present, so host-level overrides win.

## Editing Guidelines

- **Shell aliases/functions**: Add to appropriate `zsh/conf.d/*.zsh` file by topic
- **PATH modifications**: `zsh/.zshenv` or `zsh/conf.d/core.zsh`
- **Environment variables**: `zsh/.zshenv` for universal, `zsh/conf.d/*.zsh` for topic-specific
- **Git config**: `git/config` (or `git/config.local` for machine-specific, gitignored)
- **SSH hosts**: Add to `ssh/config.d/` for host-specific configs
- **New tool config**: Create new directory if XDG-compliant, otherwise add symlink in `setup.sh`
- **Secrets**: Use 1Password CLI via `zsh/secrets.zsh`, never commit secrets

## Coding Guidelines

Use zsh syntax for shell scripts. Code should be simple, portable, efficient, clearly documented, and use semantic naming.
