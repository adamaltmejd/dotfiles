# Claude Code Instructions

XDG-compliant macOS dotfiles. This repo is cloned directly to `~/.config`.

## Structure

- `zsh/` - ZDOTDIR, all zsh configuration
- `zsh/conf.d/` - Topic-based shell configs (core.zsh, git.zsh, macos.zsh, node.zsh, python.zsh, r.zsh)
- `git/` - Git config (XDG native location)
- `r/` - R configs (Rprofile, Renviron, Makevars, lintr; symlinked to ~/)
- `radian/` - Radian R console config
- `ssh/` - SSH config (included by ~/.ssh/config), with config.d/ for host-specific configs
- `ansible/` - Ansible config (vault password file)
- `system/` - Brewfile, setup.sh

## Key Files

| File | Purpose |
|------|---------|
| `system/setup.sh` | Main setup script for new machines |
| `system/Brewfile` | Homebrew packages and casks |
| `zsh/.zshrc` | Interactive shell config |
| `zsh/.zshenv` | Environment variables (sourced by bootstrap) |
| `zsh/secrets.zsh` | 1Password secrets loader |
| `zsh/conf.d/*.zsh` | Topic-specific shell configuration |
| `git/config` | Git configuration |

## Bootstrap

A minimal `~/.zshenv` (written by setup.sh) sets XDG vars and ZDOTDIR, then sources `~/.config/zsh/.zshenv`.

## Editing Guidelines

- **Shell aliases/functions**: Add to appropriate `zsh/conf.d/*.zsh` file by topic
- **PATH modifications**: `zsh/.zshenv` or `zsh/conf.d/core.zsh`
- **Environment variables**: `zsh/.zshenv` for universal, `zsh/conf.d/*.zsh` for topic-specific
- **Git config**: `git/config` (or `git/config.local` for machine-specific, gitignored)
- **SSH hosts**: Add to `ssh/config.d/` for host-specific configs
- **New tool config**: Create new directory if XDG-compliant, otherwise add symlink to setup.sh
- **Secrets**: Use 1Password CLI via `zsh/secrets.zsh`, never commit secrets

## Coding Guidelines

Use zsh syntax for shell scripts. Code should be simple, portable, efficient, clearly documented, and use semantic naming.