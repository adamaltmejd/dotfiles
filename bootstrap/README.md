# Bootstrap Internals

This directory contains implementation details for `../bootstrap.sh`.

## Layout

- `lib/`: shell helper modules
  - `common.sh`: logging, dry-run execution, shared utility functions
  - `detect.sh`: OS/package-manager/sudo capability detection
  - `link.sh`: backup-aware file writing and symlink operations
  - `packages.sh`: package list parsing and package-manager install logic
- `packages/`: package manifests
  - `packages.shared.txt`: installed for all profiles
  - `packages.local.txt`: local profile packages
  - `packages.server.txt`: server profile packages

## Design Goals

- Idempotent: safe to run multiple times.
- Transparent: all planned actions visible in `--dry-run` output.
- Capability-aware: works on hosts without sudo.
- Profile-driven: local and server behavior stays explicit.
