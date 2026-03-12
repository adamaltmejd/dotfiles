# Local Profile Notes

The local profile targets macOS and other desktop-like environments.

## Scope
- Includes shared shell/git/R setup.
- Includes local developer extras (for example Claude/Codex config links).
- May include OS-specific phases such as defaults tuning in a later step.
- Keeps local-only integrations local-only (`claude/`, `codex/`).
- Keeps R dotfiles enabled by default.

## Local Overrides
Use both override layers:
- Tool-scoped co-located untracked `*.local` files (for example `zsh/conf.d/local.zsh`, `ssh/config.d/*.local`).
- Optional host-wide untracked `~/.config/dotfiles/host.local` for cross-tool machine settings.
- Precedence: `host.local` is loaded last and overrides earlier settings when conflicts exist.
