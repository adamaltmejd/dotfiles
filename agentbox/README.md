# agentbox

The [pi](https://pi.dev) coding agent in a disposable Apple `container`
micro-VM, with enforced network egress control. Built to trial alternative
models through [opencode](https://opencode.ai) without giving an agent your
filesystem, your credentials, or your network.

```sh
agentbox build          # once, and after changing the Containerfile
cd ~/some/project
agentbox run            # pi, scoped to this directory
```

## Why

A coding agent reads files, runs shell commands, and installs what it decides
it needs. pi's own docs are explicit that it ships **no sandbox** — no
per-call approval prompt, no permission model — and that containerisation is
the intended way to contain it. Run it on the host and it implicitly gets
`~/.ssh`, `~/.aws`, every other client's repo on the disk, and your network
identity.

The threat that matters here is not a malicious agent. It is a prompt
injection in a dependency's README, or a test fixture, turning a capable
agent into an exfiltration path for whatever it can read.

## The boundary

Three layers, in order of how much they are load-bearing:

**1. A VM per session.** Apple's `container` gives each container its own
micro-VM. The isolation claim is a virtualization boundary, not namespace
hardening — which is also why this is not Docker Desktop, where every
container shares one Linux kernel. `--rm` discards the VM on exit.

**2. A host-only network.** The `agentbox` network is created `--internal`.
Verified behaviour from inside it:

| Destination | Reachable |
|---|---|
| Internet, directly | no |
| Your LAN (router, other hosts) | no |
| Your tailnet | no |
| The host itself | yes |

On the *default* container network the LAN **is** reachable, which is why
this uses its own network rather than the default.

**3. A default-deny egress allowlist.** `proxy/allowlist.txt` lists the
domains the agent may reach; squid on the host refuses everything else with
403 and logs every connection. The env vars are not the enforcement — the
host-only network means a process that ignores `HTTPS_PROXY` has no route at
all. The proxy is the only door, and it keeps the log.

Deliberately *not* claimed: this does not protect the contents of
`/workspace`. An agent with a legitimate route to opencode.ai can put your
source code in a prompt. Mount only what the task needs.

## Session lifecycle

`agentbox build` is a one-off (and after you change the `Containerfile`).
`agentbox run` starts a fresh micro-VM each time — it does not rebuild.

Exactly two host directories are mounted, nothing else:

| Mount | Purpose |
|---|---|
| `$PWD` → `/workspace` | the project, read-write |
| `agentbox/pi` → `~/.pi/agent` | provider config and `AGENTS.md` |
| `~/.local/state/agentbox/sessions/<project>` → `~/.pi/sessions` | this project's history |

On exit, `--rm` discards the VM and everything written outside those mounts.
What survives:

- **Your project.** Edits under `/workspace` are on the host filesystem, owned
  by you (the image builds a user at uid 501), so no `chown` dance.
- **Session history**, per project, under
  `~/.local/state/agentbox/sessions/`. `agentbox run --continue` resumes the
  session for *that* directory. pi keys its history by working directory,
  which is always `/workspace` inside the container, so without this every
  project would share one history — the run script gives each project path
  its own directory instead.
- **The egress log**, at `~/.local/state/agentbox/egress.log`.

What does not survive: installed packages, anything written to `/tmp` or the
home directory, and the VM itself. The squid proxy keeps running on the host
between sessions (`agentbox proxy stop` to stop it), and Apple's `buildkit`
builder container stays up after a build; neither is your agent.

## Layout

```
Containerfile        debian-slim + pi + the tools, no Node and no npm anywhere
agentbox.sh          build / run / shell / proxy / doctor / clean
vendor.lock          pinned sha256 for every binary baked into the image
proxy/squid.conf.in  proxy config template
proxy/allowlist.txt  the domains the agent may reach -- edit this
pi/AGENTS.md         the agent's operating contract, loaded every session
pi/models.json       opencode provider and model definitions
```

`vendor/` (gitignored) holds the pinned binaries; `agentbox vendor` fetches
and checksums them.

## Tools in the image

`pi`, `rg`, `fd`, `ast-grep`, `jq`, `tree`, `git`, `shellcheck`, `shfmt`,
`uv`, `bun`. This mirrors the tool defaults in `~/.config/CLAUDE.md`, so the
agent can run the same checks you would — an agent that cannot verify its own
work only produces plausible-looking diffs.

pi ships a standalone `linux-arm64` binary, so there is no Node and no npm on
the host *or* in the image. bun provides the JS runtime for project work.

ast-grep is installed as `ast-grep` only. Its release also ships an `sg`
shim, which would shadow Debian's setgid `sg`; that one is not installed.

## The API key

Never baked into the image, never written to disk, never in the container's
argv. `agentbox run` resolves it on the host and passes it by name:

```sh
op read op://Private/opencode/credential     # what it does by default
```

Override the reference with `AGENTBOX_OP_REF`, or just export
`OPENCODE_API_KEY` yourself. `pi/models.json` refers to it as
`"apiKey": "$OPENCODE_API_KEY"`.

## Changing what the agent can reach

Edit `proxy/allowlist.txt` (one domain per line, a leading dot covers
subdomains), then:

```sh
agentbox proxy stop && agentbox proxy start
```

Check what it actually talked to:

```sh
agentbox proxy log -n 50
```

## Running over SSH and tmux

`tmux/tmux.conf` sets `extended-keys on` and `extended-keys-format csi-u`.
Without these, tmux strips modifier information and pi cannot distinguish
`Shift+Enter` from `Enter`, which breaks its editing keys. Needs tmux 3.5+
(you have 3.7c) and a terminal that supports extended keys — Ghostty does.
Run tmux on the host and `agentbox run` inside it: if the SSH connection
drops, the session survives.

## Known rough edges

- **No DNS in the container**, by design (`--no-dns`). The proxy resolves
  names on the host. Anything expecting to resolve names itself will fail.
- **The container can reach any port on the host**, not just the proxy — a
  consequence of the vmnet gateway not being a bindable host interface, so
  squid must listen on `0.0.0.0`. Its ACL restricts clients to the container
  subnets, but other host services bound to `0.0.0.0` are reachable. Close
  this with `pf` rules if it matters to you.
- **No git remote access.** No credentials are forwarded, so the agent can
  read public repositories but cannot push. Commit inside, push from the host.
- **Model metadata in `pi/models.json` is approximate.** opencode's `/models`
  endpoint returns IDs only, not context windows or pricing, so
  `contextWindow`/`maxTokens` are conservative starting values and `cost` is
  zeroed — the cost display will read 0, not your actual spend. Adjust
  against opencode's docs if that matters.
- **Builds go through the proxy too.** The builder VM has no IPv6 route and
  intermittently fails to reach AAAA-first mirrors directly, so `apt` is
  pointed at the same allowlist. A build needs `deb.debian.org` allowed.

## Troubleshooting

`agentbox doctor` reports the state of every moving part. Common failures:

- *squid not answering* — something else holds port 8888, or the config was
  rejected. `squid -f ~/.local/state/agentbox/squid.conf -k parse`.
- *403 from the proxy* — the domain is not in `allowlist.txt`. The egress log
  names it.
- *container cannot reach the model* — check `agentbox doctor` shows the
  proxy answering, then confirm the gateway in `agentbox doctor` matches the
  `HTTPS_PROXY` the container was given.
