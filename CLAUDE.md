# Claude Code Instructions

XDG-compliant dotfiles for macOS/Linux. Lives at `~/.config`.

## Structure

Each tool has its own directory (`zsh/`, `git/`, `r/`, `ssh/`, etc.) using XDG-native paths where possible. Non-XDG tools are symlinked by `setup.sh`. Full layout in `README.md`.

- `setup/` — bootstrap, setup script, helper modules, package manifests, macOS defaults
  - `bootstrap.sh` — curl-to-bash installer (`curl -fsSL https://raw.githubusercontent.com/adamaltmejd/dotfiles/main/setup/bootstrap.sh | bash`)
  - `setup.sh` — idempotent entry point. `--profile` required (`local`/`server`). See `--help`.
  - `lib/common.sh` generates `~/.zshenv` (XDG vars, `DOTFILES_DIR`, `ZDOTDIR`), which sources `zsh/.zshenv`. Never hand-edit `~/.zshenv`.
  - `profile` — generated feature flags (gitignored). `.zshrc` exposes them as `feat <name>`; gate optional-tool config in `conf.d/` with it.
  - `macos/remote-ssh/` — `--with-remote-ssh` installer with its own test harness
- `agents/` — AI agent configs, symlinked into `~/.claude`, `~/.codex`, `~/.agents` by `setup.sh`
  - `claude/CLAUDE.md` **is** `~/.claude/CLAUDE.md` (global instructions). `codex/AGENTS.md` is a manual copy — keep in sync.
  - `skills/` — gitignored except locally authored skills, which need an explicit `!` entry

## Editing guidelines

- `.gitignore` uses an allowlist — new files are **ignored by default**, add explicit `!` entries to track them
- Shell aliases/functions/env vars: appropriate `zsh/conf.d/*.zsh` file by topic
- PATH and universal env vars: `zsh/.zshenv`
- Per-machine overrides: `zsh/local.zsh` (gitignored)
- Zsh plugins: `zsh/plugins.txt` (antidote); `plugins.zsh` is generated
- SSH hosts: `ssh/config.d/` (`*.local` gitignored)
- New tool: own directory if XDG-native, otherwise add symlink in `setup.sh`
- Secrets via direnv + 1Password CLI. Templates with `op://` refs in `zsh/secrets/`. Custom `use_op` in `direnv/direnvrc` resolves and caches. Per-project `.envrc` loads secrets with `use op <template>`; `use op --lazy …` defers resolution to `oprun <cmd>` (never cached, never in shell env). `direnvrc` header documents both.

## Package manager supply chain safety

Global configs (`uv/uv.toml`, `.bunfig.toml`) enforce a 7-day minimum release age on packages. If a `bun install` or `uv` resolution fails because a recently published version is filtered out, **do not bypass the age gate**. Instead: pin an older version that satisfies the constraint, or flag the issue to the user. bun disables lifecycle scripts by default and is the only JS package manager configured (`npx` is aliased to `bunx`; there is no npmrc).

## Verification

No CI. Before finishing shell changes:

```sh
shellcheck -x -P SCRIPTDIR setup/setup.sh setup/bootstrap.sh setup/macos/remote-ssh/install.sh
for f in zsh/.zshenv zsh/.zshrc zsh/conf.d/*.zsh; do zsh -n "$f"; done
bash setup/setup.sh --profile local --dry-run --skip-packages
bash setup/macos/remote-ssh/tests/test-install.sh   # macOS only, runs in a temp dir
```

## Coding style

Simple, portable, efficient, semantic naming. `setup/` is bash (`set -euo pipefail`, 4-space indent); `zsh/` and `setup/macos-defaults.zsh` are zsh. shfmt is installed but not enforced — don't reformat unrelated lines.
