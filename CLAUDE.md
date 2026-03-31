# Claude Code Instructions

XDG-compliant dotfiles for macOS/Linux. Lives at `~/.config`.

## Structure

Each tool has its own directory (`zsh/`, `git/`, `r/`, `ssh/`, etc.) using XDG-native paths where possible. Non-XDG tools are symlinked by `setup.sh`. Full layout in `README.md`.

- `setup/` — bootstrap, setup script, helper modules, package manifests, macOS defaults
  - `bootstrap.sh` — curl-to-bash installer (`curl -fsSL .../setup/bootstrap.sh | bash`)
  - `setup.sh` — idempotent entry point. `--profile` required (`local`/`server`). See `--help`.
- `agents/` — AI agent configs

## Editing guidelines

- `.gitignore` uses an allowlist — new files are **ignored by default**, add explicit `!` entries to track them
- Shell aliases/functions/env vars: appropriate `zsh/conf.d/*.zsh` file by topic
- PATH and universal env vars: `zsh/.zshenv`
- Per-machine overrides: `zsh/local.zsh` (gitignored)
- SSH hosts: `ssh/config.d/` (`*.local` gitignored)
- New tool: own directory if XDG-native, otherwise add symlink in `setup.sh`
- Secrets via direnv + 1Password CLI. Templates with `op://` refs in `zsh/secrets/`. Custom `use_op` in `direnv/direnvrc` resolves and caches. Per-project `.envrc` loads secrets with `use op <template>`

## Package manager supply chain safety

Global configs (`uv/uv.toml`, `.bunfig.toml`) enforce a 7-day minimum release age on packages. If a `bun install` or `uv` resolution fails because a recently published version is filtered out, **do not bypass the age gate**. Instead: pin an older version that satisfies the constraint, or flag the issue to the user. bun disables lifecycle scripts by default; npm uses `ignore-scripts=true`.

## Coding style

Zsh syntax for shell scripts. Simple, portable, efficient, semantic naming.
