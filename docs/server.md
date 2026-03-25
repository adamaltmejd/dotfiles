# Server Profile Notes

The server profile targets Linux/Unix remote systems.

## Scope
- Includes shared shell/git setup.
- Keeps the same core shell stack as local, but with a heavily reduced plugin/prompt footprint.
- Avoids local-only integrations (1Password, macOS defaults, python/pip shims).
- Keeps setup broadly useful across host types (R is skipped by default; use `--with-r` to opt in).

## Local Overrides
Use both override layers:
- Tool-scoped co-located untracked `*.local` files.
- Optional host-wide untracked `~/.config/dotfiles/host.local` for cross-tool server settings.
- Precedence: `host.local` is loaded last and overrides earlier settings when conflicts exist.
