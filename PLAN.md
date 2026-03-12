# Dotfiles Modernization Plan

## Goal
Unify local and server dotfiles into one maintainable system with:

- One source of truth in version control.
- Clear separation of shared config vs environment-specific overlays.
- Idempotent, non-interactive bootstrap for servers and local machines.
- Graceful operation on hosts without `sudo`.

## Guiding Principles

1. Keep runtime behavior simple: shared base + selected profile.
2. Stay XDG-first (`~/.config`, `~/.local/share`, `~/.local/state`, `~/.cache`) and limit legacy top-level dotfiles.
3. Use a custom, idempotent linker (`bootstrap/lib/link.sh`) and do not use `stow`.
4. Keep installs optional and capability-aware (`sudo` / package manager detection).
5. Keep machine-specific secrets out of git (`*.local` files).
6. Make bootstrap safe to re-run and safe by default (`--dry-run` first).

## Decisions (2026-02-22)

1. Dotfiles install path policy: default `XDG_CONFIG_HOME` is `~/.config`, but custom `XDG_CONFIG_HOME` paths are supported.
2. Legacy import timing: move `server-config/` into `legacy/server-config/` now.
3. Server shell strategy: keep the same core shell stack as local, but with a heavily reduced plugin/prompt footprint and only broadly useful tooling.
4. Package policy: warn and continue when installs are unavailable/skipped.
5. Local-only integrations: keep `claude/` and `codex/` links local-only.
6. Overrides model: support both co-located `*.local` files and a host-level `~/.config/dotfiles/host.local`.
7. Legacy setup script policy: remove legacy `setup.sh` and use `bootstrap.sh` only.

## Proposed Layout

```text
dotfiles/
  bootstrap.sh
  bootstrap/
    lib/
      common.sh
      link.sh
      detect.sh
      packages.sh
    packages/
      packages.shared.txt
      packages.server.txt
      packages.local.txt
  zsh/
  git/
  ssh/
  r/
  radian/
  macos/
    apply-defaults.zsh
    packages.Brewfile
  claude/
  codex/
  docs/
    server.md
    local.md
  legacy/
    server-config/         # temporary landing area during migration
```

Notes:

- Keep managed config under `XDG_CONFIG_HOME` (`~/.config` by default).
- Keep minimal top-level files only when required by tool behavior (`~/.zshenv`, `~/.ssh/config`, R startup symlinks).

## Config Layering Model

Order in shell startup:

1. Shared defaults.
2. Selected profile (`server` or `local`).
3. Tool-scoped co-located overrides (`*.local`, gitignored).
4. Host-level override file (`~/.config/dotfiles/host.local`, gitignored).

This gives one source of truth while supporting controlled divergence.

## Bootstrap Contract

Target CLI:

```bash
./bootstrap.sh --profile server --dry-run
./bootstrap.sh --profile server --apply
./bootstrap.sh --profile local --apply
```

Recommended behavior:

- `--profile {server|local}` required.
- `--dry-run` prints planned link/install actions.
- `--apply` performs actions.
- `--xdg-config-home <path>` sets default `XDG_CONFIG_HOME` for generated bootstrap env.
- `--with-r` / `--without-r` override profile defaults for R dotfiles.
- `--skip-packages` only links config.
- `--no-sudo` forces user-space install path.
- `--backup-dir <path>` for replaced files.

Bootstrap phases:

1. Detect OS + package manager + sudo capability.
2. Ensure user dirs exist (`~/.local/bin`, XDG dirs).
3. Link files with the custom linker (`bootstrap/lib/link.sh`).
4. Install packages if requested and possible.
5. Print post-setup checks.

## Server vs Local Divergence Policy

Expected split:

- Shared: 70-85%
  - shell core, aliases, git defaults, tmux basics, editor defaults.
- Server-only: 15-30%
  - no GUI dependencies, lower prompt cost, safer aliases, ops helpers.
- Local-only: 15-30%
  - GUI/dev tools, richer prompt/theme, desktop integrations.

Server profile constraints:

- Assume no root.
- Prefer user-level tools (`~/.local/bin`).
- Avoid hard dependency on plugin managers that require interactive setup.
- Keep default server setup broadly useful across host types (for example, skip R by default and allow explicit opt-in).
- Avoid assumptions about locale/timezone unless explicitly desired.

## Migration Phases

### Phase 0: Import and Freeze

1. Move current `server-config` into `legacy/server-config`.
2. Remove legacy `setup.sh`; route all setup through `bootstrap.sh`.
3. Record current behavior in `docs/server.md`.

### Phase 1: Build Shared Base

1. Extract reusable files from legacy (`aliases`, `exports`, `tmux`, `git`, zsh core).
2. Normalize paths to XDG where practical.
3. Keep install-path contract explicit:
   - `XDG_CONFIG_HOME` defaults to `~/.config` but can be overridden.

### Phase 2: Add Profiles

1. Create `profile-server` and `profile-local` overlays.
2. Move environment-specific exports/aliases into overlays.
3. Support both tool-scoped `*.local` files and host-level `~/.config/dotfiles/host.local`.

### Phase 3: Bootstrap Rewrite

1. Implement `bootstrap.sh` with `--dry-run` and `--apply`.
2. Make linking idempotent and backup-aware.
3. Add capability detection and no-sudo behavior.
4. Keep output concise and actionable.

### Phase 4: Package Strategy

1. Define package lists by scope:
   - `shared`, `server`, `local`.
2. Install only when a supported package manager is found.
3. If unsupported or unprivileged, print manual steps instead of failing hard.

### Phase 5: Validation

1. Fresh server account test (no sudo).
2. Existing server account test (pre-existing dotfiles).
3. Local machine test with full profile.
4. Re-run bootstrap twice to confirm idempotency.

### Phase 6: Cutover

1. Validate one successful `bootstrap.sh --apply` on a local host and one server host.
2. Keep `bootstrap.sh` as the only supported setup entrypoint.
3. Remove `legacy/server-config` after confidence window.

## Minimum Acceptance Checklist

- `bootstrap.sh --profile server --dry-run` shows valid plan.
- `bootstrap.sh --profile server --apply` succeeds without sudo.
- Existing files are backed up before replacement.
- Shell startup has no missing-file errors.
- Re-running bootstrap makes no destructive changes.
- Local profile still supports your normal development workflow.
- Legacy `setup.sh` is removed.
