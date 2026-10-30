# Dotfiles

XDG-compliant dotfiles for macOS and Linux, with profile-aware setup.

Interactive shells use Bash 5.1+ (Homebrew Bash on macOS). Environment setup
is separate from interactive aliases, prompt hooks, completion and SSH/tmux
attachment. Ordinary noninteractive `bash -c` commands inherit their caller's
environment; there is no global `BASH_ENV` injection.

## Install

One-liner for a fresh machine (requires `curl` and `bash`):

```bash
curl -fsSL https://raw.githubusercontent.com/adamaltmejd/dotfiles/main/setup/bootstrap.sh | bash
```

This auto-detects your OS (macOS → `local`, Linux → `server`), installs git if needed, clones the repo to `~/.config`, and runs setup.

### Options

```bash
# Explicit profile
curl -fsSL .../bootstrap.sh | bash -s -- --profile server

# Preview without applying
curl -fsSL .../bootstrap.sh | bash -s -- --dry-run

# Enable specific features on server
curl -fsSL .../bootstrap.sh | bash -s -- --with-claude --with-starship
```

### Manual setup

```bash
git clone https://github.com/adamaltmejd/dotfiles.git ~/.config
cd ~/.config
./setup/setup.sh --profile local --dry-run   # preview
./setup/setup.sh --profile local             # run (prompts for confirmation)
exec bash -l   # /opt/homebrew/bin/bash -l on Apple Silicon macOS
```

On macOS, install Xcode CLI tools first: `xcode-select --install`

## What it does

Setup writes minimal `~/.bash_profile` and `~/.bashrc` entrypoints pointing at
`bash/bashrc`. That file loads `bash/env.bash` before returning for
noninteractive invocations, including SSH commands that source `.bashrc`.
Interactive shells then load the profile flags and `bash/conf.d/*.bash`.
Setup does not change the account's login shell or `/etc/shells`.

### Migration from zsh

Keep an existing terminal open throughout cutover. Start with this machine and
account; migrate other Macs, Linux hosts and the restricted runner separately.

1. Before applying setup, run `bash setup/tests/test-bash.sh`, ShellCheck and
   the setup dry run. Use Homebrew Bash for the test harness. Do not apply setup
   from a review worktree: its generated files would point at that checkout.
2. After review, apply setup from the permanent dotfiles checkout. Preview
   feature flags explicitly; an existing generated `setup/profile` is not read
   as the installer's feature defaults. Avoid re-enabling unrelated features.
3. Test `/opt/homebrew/bin/bash -l` in a new terminal. Verify uv, Bun, Rust, R,
   direnv, `oprun`, completion, fzf history search and command failure prompts.
   The first version omits zsh's autosuggestions, syntax highlighting and
   transient prompt. Starship's normal prompt remains.
4. Update existing project `.envrc` files from `~/.config/zsh/secrets/` to
   `~/.config/secrets/`, then review/allow the changed direnv files. Old paths
   intentionally fail until updated; there is no compatibility symlink. Custom,
   ignored templates and `local.zsh` overrides need a separate inventory and
   Bash port; never copy or print resolved secret values.
5. Back up existing home startup files. Remove obsolete Docker Desktop PATH
   blocks from `~/.profile` and `~/.zprofile`; they are not carried into Bash.
   If `.profile` contains other local settings, migrate those deliberately:
   Bash reads `.bash_profile` instead once it exists. Port any ignored
   `zsh/local.zsh` settings to `bash/local.bash`.
6. On this Apple Silicon Mac, register `/opt/homebrew/bin/bash` in `/etc/shells`
   (requires administrator access), then run
   `chsh -s /opt/homebrew/bin/bash`. Use the Homebrew prefix appropriate to
   each other host. Do not select Apple's `/bin/bash` 3.2.
7. Open fresh terminal and agent sessions. Confirm the executing shell and
   version, not only `$SHELL`, and check selected nonsecret environment values
   and tool paths. A GUI-launched agent may need a fresh application launch;
   verify its actual execution environment rather than adding a global
   `BASH_ENV` workaround.
8. Verify incoming interactive SSH, a noninteractive SSH command, and
   `DOTFILES_NO_AUTO_TMUX=1`. Confirm SSH terminfo installation and mouse
   behavior in Ghostty. Existing tmux servers can retain the old default
   shell: inspect `tmux show-options -g default-shell`, and set the verified
   host-specific Bash path for new panes if necessary. Leave running panes
   and jobs intact. Zellij's new sessions select Bash; restored sessions may
   still contain zsh processes.

Rollback: restore the previous login shell (normally `chsh -s /bin/zsh`) and
open a fresh terminal. The legacy `zsh/` configuration and existing `~/.zshenv`
are retained during rollout; setup does not overwrite them. Restore the
backed-up `.bashrc`/`.bash_profile` if needed. Ghostty detects either shell.
Only remove the legacy shell configuration after the real
terminal, agent, project and SSH checks pass on the intended hosts.

### Profiles

| | `local` (macOS default) | `server` (Linux default) |
|---|---|---|
| Shell + git config | yes | yes |
| Packages | full Brewfile + shared | shared + htop + zellij |
| [Modern CLI tools](#modern-cli-tools) | yes (starship, eza, bat, fd, fzf, zoxide) | no |
| direnv | yes | no |
| R dotfiles | yes | no |
| Claude/Codex config | yes | no |
| Tailscale-only inbound SSH | opt-in | no |
| Python/pip shims (enforce uv) | yes | no |

Override any feature with `--with-<feature>` or `--without-<feature>`.

### Tailscale-only inbound SSH

The macOS `remote-ssh` feature installs a key-only OpenSSH configuration and
restricts TCP/22 to explicitly enrolled Tailscale clients with `pf`. It is
deliberately off by default because it enables a network service.

1. Put one distinct **public** key per enrolled device in
   `ssh/authorized_keys/<device>.pub`. Never add a private key to this repo.
2. Confirm each device's key name, Tailscale DNS name, and OS in
   `setup/macos/remote-ssh/config`.
3. Preview and apply:

   ```bash
   ./setup/setup.sh --profile local --with-remote-ssh --dry-run
   ./setup/setup.sh --profile local --with-remote-ssh
   ```

The installer discovers the devices' current Tailscale IPv4 addresses, excludes
the server itself, binds each key to its source address, and validates the
generated `sshd` and `pf` configurations before installing them. It never
symlinks root configuration into the user-writable dotfiles checkout. See
`setup/macos/remote-ssh/README.md` for verification and recovery.

### Remote tmux

Interactive SSH sessions on the Macs automatically create or attach to a
persistent tmux session named `main`. The top status bar shows the Tailscale
machine name prominently. The command prefix is `§`: use `§ d` to detach while
leaving work running, or press `§` twice to send a literal section sign.

To request a one-off bare remote shell:

```bash
ssh -t macmini 'DOTFILES_NO_AUTO_TMUX=1 exec bash -il'
```

### What setup touches

| Target | Action |
|--------|--------|
| `~/.bash_profile`, `~/.bashrc` | Written (Bash entrypoints and XDG defaults) |
| `~/.ssh/config` | Written (Include directive) |
| `~/.local/bin/python`, `pip` | Shims enforcing `uv` (local only) |
| `~/.config/setup/profile` | Feature flags for shell to read |
| `~/.Rprofile`, `~/.Renviron`, etc. | Symlinked (if R enabled) |
| `~/.claude/`, `~/.codex/`, `~/.agents/` | Symlinked from `agents/` (if claude enabled) |

Existing files are backed up to `~/dotfiles-backup/<timestamp>/` before replacement.

## Modern CLI tools

Installed on `local` profile (or with `--with-smartcli`):

| Tool | Replaces | Usage |
|------|----------|-------|
| `eza` | `ls` | Aliased to `ls`, `l`, `la`, `tree` |
| `bat` | `cat` | Aliased to `cat`, also used as man pager |
| `ripgrep` | `grep` | `rg` |
| `fd` | `find` | `fd` |
| `zoxide` | `cd` | `z <partial>` |
| `fzf` | — | Ctrl+R history, Ctrl+T files |
| `starship` | prompt | Cross-shell prompt |
| `delta` | git diff | Automatic via gitconfig |

## Secrets

Managed via 1Password CLI (`op`) and direnv. Templates in `secrets/` contain `op://` references. A custom `use_op` direnv function (defined in `direnv/direnvrc`) resolves references via `op inject`, caches the result, and exports as env vars.

Usage in any `.envrc`:
```bash
use op ~/.config/secrets/base.env            # global secrets
use op .secrets.env.tpl                       # project-specific (optional)
dotenv_if_exists .secrets.env                 # plaintext overrides (optional)
```

On servers without `op`/direnv: use `secrets/local.sh` (plaintext, gitignored).
This is Bash source, unlike the dotenv templates. `oprun` is an interactive
Bash function; scripts needing it must explicitly source
`bash/conf.d/secrets.bash` in an initialized environment.

## Repository layout

```
dotfiles/
├── setup/
│   ├── bootstrap.sh        # curl-to-bash entry point
│   ├── setup.sh            # main setup script
│   ├── lib/                # detection, linking, package helpers
│   ├── macos-defaults.sh   # macOS system defaults
│   ├── macos/              # remote-ssh (Tailscale-only sshd) installer + tests
│   └── packages/           # package manifests (shared, local, server, Brewfile)
├── bash/                   # env.bash, bashrc, conf.d/, prompt and tips
├── secrets/                # op:// dotenv templates; local.sh is ignored
├── zsh/                    # Legacy configuration retained during cutover
├── direnv/                 # direnvrc with use_op helper
├── git/                    # git config
├── ssh/                    # ssh config + config.d/ for hosts
├── r/                      # Rprofile, Renviron, Makevars, lintr
├── radian/                 # radian console config
├── cargo/                  # config.toml (sccache), linked into CARGO_HOME
├── tmux/                   # auto-attached macOS SSH session + host status
├── zellij/                 # zellij multiplexer config (server use)
├── agents/                 # AI agent configs + shared skills
│   ├── claude/             # Claude Code settings
│   ├── codex/              # Codex CLI config + rules
│   └── skills/             # shared skills (symlinked to ~/.claude/skills)
├── ansible/                # ansible config
├── gh/                     # GitHub CLI config
├── ghostty/                # ghostty terminal config
├── zed/                    # Zed editor settings.json
└── uv/                     # uv.toml (7-day minimum release age)
```

## License

MIT
