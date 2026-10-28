# Claude Code Instructions

XDG-compliant dotfiles for macOS/Linux. Lives at `~/.config`.

## Structure

Each tool has its own directory (`bash/`, `git/`, `r/`, `ssh/`, etc.) using XDG-native paths where possible. Non-XDG tools are symlinked by `setup.sh`. Full layout and staged Bash cutover in `README.md`.

- `setup/` — bootstrap, setup script, helper modules, package manifests, macOS defaults
  - `bootstrap.sh` — curl-to-bash installer (`curl -fsSL https://raw.githubusercontent.com/adamaltmejd/dotfiles/main/setup/bootstrap.sh | bash`)
  - `setup.sh` — idempotent entry point. `--profile` required (`local`/`server`). See `--help`.
  - `lib/common.sh` generates `~/.bash_profile` and `~/.bashrc`, which load `bash/bashrc`. Never hand-edit generated entrypoints. Setup does not change the login shell.
  - `profile` — generated feature flags (gitignored). `bash/bashrc` exposes them as `feat <name>`; gate optional-tool config in `conf.d/` with it.
  - `macos/remote-ssh/` — `--with-remote-ssh` installer with its own test harness
- `agents/` — AI agent configs, symlinked into `~/.claude`, `~/.codex`, `~/.agents` by `setup.sh`
  - `claude/CLAUDE.md` **is** `~/.claude/CLAUDE.md` (global instructions). `codex/AGENTS.md` is a manual copy — keep in sync.
  - `skills/` — gitignored except locally authored skills, which need an explicit `!` entry

## Editing guidelines

- `.gitignore` uses an allowlist — new files are **ignored by default**, add explicit `!` entries to track them
- Shell aliases/functions: appropriate `bash/conf.d/*.bash` file by topic
- PATH and environment vars: `bash/env.bash`, loaded before the interactive guard; no global `BASH_ENV`
- Interactive Bash requires 5.1+; on macOS use Homebrew Bash, not `/bin/bash` 3.2
- Per-machine overrides: `bash/local.bash` (gitignored)
- `zsh/` is legacy rollback configuration. Do not add new features there or remove it until live cutover checks pass.
- SSH hosts: `ssh/config.d/` (`*.local` gitignored)
- New tool: own directory if XDG-native, otherwise add symlink in `setup.sh`
- Secrets via direnv + 1Password CLI. Templates with `op://` refs in `secrets/`. Custom `use_op` in `direnv/direnvrc` resolves and caches. Per-project `.envrc` loads secrets with `use op <template>`; `use op --lazy …` defers resolution to `oprun <cmd>` (never cached, never in shell env). `direnvrc` header documents both. The old base-template symlink exists only for staged migration of project references.

## Package manager supply chain safety

Global configs (`uv/uv.toml`, `.bunfig.toml`) enforce a 7-day minimum release age on packages. If a `bun install` or `uv` resolution fails because a recently published version is filtered out, **do not bypass the age gate**. Instead: pin an older version that satisfies the constraint, or flag the issue to the user. bun disables lifecycle scripts by default and is the only JS package manager configured (`npx` is aliased to `bunx`; there is no npmrc).

## Verification

No CI. Before finishing shell changes:

```sh
shellcheck -x -P SCRIPTDIR setup/setup.sh setup/bootstrap.sh setup/macos/remote-ssh/install.sh
shellcheck -x -P SCRIPTDIR bash/env.bash bash/bashrc bash/conf.d/*.bash setup/lib/*.sh setup/tests/test-bash.sh
bash setup/tests/test-bash.sh  # Homebrew Bash on macOS
bash setup/setup.sh --profile local --dry-run --skip-packages --without-remote-ssh
bash setup/macos/remote-ssh/tests/test-install.sh   # macOS only, runs in a temp dir
```

## Coding style

Simple, portable, efficient, semantic naming. Standalone Bash scripts use `set -euo pipefail` where appropriate and 4-space indent. Never enable script strict mode in interactive startup. Keep the setup entrypoint usable with Apple's Bash 3.2 so it can install modern Bash. shfmt is installed but not enforced — don't reformat unrelated lines.
