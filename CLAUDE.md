# Claude Code Instructions

XDG-compliant macOS dotfiles. This repo is cloned directly to `~/.config`.

## Structure

- `zsh/` - ZDOTDIR, all zsh configuration
- `zsh/conf.d/` - Topic-based shell configs (git.zsh, python.zsh, etc.)
- `git/` - Git config (XDG native location)
- `r/` - R configs (symlinked to ~/.Rprofile, ~/.Renviron)
- `ssh/` - SSH config (included by ~/.ssh/config)
- `system/` - Brewfile, setup.sh, macOS defaults

## Key Files

| File | Purpose |
|------|---------|
| `system/setup.sh` | Main setup script for new machines |
| `zsh/.zshrc` | Interactive shell config |
| `zsh/.zshenv` | Environment variables (sourced by bootstrap) |
| `zsh/conf.d/*.zsh` | Topic-specific shell configuration |
| `git/config` | Git configuration |

## Bootstrap

A minimal `~/.zshenv` (written by setup.sh) sets XDG vars and ZDOTDIR, then sources `~/.config/zsh/.zshenv`.

## Editing Guidelines

- **Shell aliases/functions**: Add to appropriate `zsh/conf.d/*.zsh` file by topic
- **PATH modifications**: `zsh/.zshenv` or `zsh/conf.d/core.zsh`
- **Environment variables**: `zsh/.zshenv` for universal, `zsh/conf.d/*.zsh` for topic-specific
- **Git config**: `git/config` (or `git/config.local` for machine-specific, gitignored)
- **New tool config**: Create new directory if XDG-compliant, otherwise add symlink to setup.sh

## Coding Guidelines

Use zsh syntax for shell scripts. Code should be simple, portable, efficient, clearly documented, and use semantic naming.

## Tools

| Tool | Replaces | Config location |
|------|----------|-----------------|
| `eza` | `ls` | `zsh/conf.d/core.zsh` |
| `bat` | `cat` | `bat/config` if customized |
| `uv` | pip/venv | `zsh/conf.d/python.zsh` |
| `bun` | npm/node | `zsh/conf.d/node.zsh` |
| `renv`+`pak` | R packages | `zsh/conf.d/r.zsh` |
