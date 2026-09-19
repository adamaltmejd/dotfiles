#!/usr/bin/env bash
# agentbox -- run the pi coding agent inside a disposable Apple container VM
# with enforced egress control. See README.md for the security model.
set -euo pipefail

IMAGE="${AGENTBOX_IMAGE:-agentbox:local}"
NETWORK="${AGENTBOX_NETWORK:-agentbox}"
SUBNET="${AGENTBOX_SUBNET:-192.168.200.0/24}"
PROXY_PORT="${AGENTBOX_PROXY_PORT:-8888}"
CPUS="${AGENTBOX_CPUS:-4}"
MEMORY="${AGENTBOX_MEMORY:-8G}"
# 1Password reference for the opencode key; resolved on the host, never stored
# in the image and never written to disk.
OP_REF="${AGENTBOX_OP_REF:-op://Private/opencode/credential}"
# Default model. pi otherwise defaults to provider "google", which is not
# configured here. Override per-run by passing --provider/--model.
PROVIDER="${AGENTBOX_PROVIDER:-opencode-go}"
MODEL="${AGENTBOX_MODEL:-glm-5.3}"
# The container network's resolver does not answer on this host, so builds
# need an explicit nameserver.
BUILD_DNS="${AGENTBOX_BUILD_DNS:-1.1.1.1}"
# The image builder runs on the default NAT network, not the host-only one;
# its subnet is allowed through the proxy so builds use the same allowlist.
BUILD_SUBNET="${AGENTBOX_BUILD_SUBNET:-192.168.64.0/24}"
BUILD_GATEWAY="${AGENTBOX_BUILD_GATEWAY:-192.168.64.1}"

# Extra container-level flags, set by `shell`; must precede the image name.
RUN_FLAGS=()
FORWARD_ENV=()
FORWARD_NAMES=()

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agentbox"
CONF="$STATE/squid.conf"
PIDFILE="$STATE/squid.pid"
LOGFILE="$STATE/egress.log"
CACHELOG="$STATE/squid.log"

die() { printf 'agentbox: %s\n' "$*" >&2; exit 1; }
info() { printf 'agentbox: %s\n' "$*" >&2; }

require() { command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"; }

ensure_network() {
    if ! container network inspect "$NETWORK" >/dev/null 2>&1; then
        info "creating host-only network $NETWORK ($SUBNET)"
        container network create --internal --subnet "$SUBNET" "$NETWORK" >/dev/null
    fi
}

gateway() {
    container network inspect "$NETWORK" \
        | sed -n 's/.*"ipv4Gateway" *: *"\([^"]*\)".*/\1/p' | head -1
}

# True when something is serving HTTP on the proxy port. Used instead of the
# PID file to confirm the proxy is actually usable.
port_answers() {
    # 000 means no listener; any HTTP status (even 403) means squid answered.
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
        -x "http://127.0.0.1:$PROXY_PORT" http://example.invalid/ 2>/dev/null)" != "000" ]
}

proxy_running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

proxy_start() {
    require squid "Install with: brew install squid"
    proxy_running && { info "proxy already running (pid $(cat "$PIDFILE"))"; return 0; }
    mkdir -p "$STATE"
    sed -e "s|@PORT@|$PROXY_PORT|g" \
        -e "s|@SUBNET@|$SUBNET|g" \
        -e "s|@BUILD_SUBNET@|$BUILD_SUBNET|g" \
        -e "s|@ACCESSLOG@|$LOGFILE|g" \
        -e "s|@CACHELOG@|$CACHELOG|g" \
        -e "s|@PIDFILE@|$PIDFILE|g" \
        -e "s|@FILTER@|$DIR/proxy/allowlist.txt|g" \
        "$DIR/proxy/squid.conf.in" > "$CONF"
    squid -f "$CONF" -k parse >/dev/null 2>&1 || die "squid rejected $CONF; run: squid -f $CONF -k parse"
    squid -f "$CONF" || die "squid failed to start; see $CACHELOG"
    # A live PID file is not proof of a working proxy: squid writes one, then
    # exits if the port is taken. Wait until the port actually answers.
    local _
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        port_answers && break
        sleep 0.5
    done
    port_answers || die "squid is not answering on :$PROXY_PORT. Last lines of $CACHELOG:
$(tail -5 "$CACHELOG" 2>/dev/null)"
    info "proxy listening on :$PROXY_PORT (allowlist: $DIR/proxy/allowlist.txt)"
}

proxy_stop() {
    proxy_running || { info "proxy not running"; return 0; }
    squid -f "$CONF" -k shutdown 2>/dev/null || kill "$(cat "$PIDFILE")" 2>/dev/null || true
    local _
    for _ in 1 2 3 4 5 6; do
        proxy_running || break
        sleep 0.5
    done
    proxy_running && kill -9 "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    info "proxy stopped"
}

# Names (never values) of environment variables to carry into the sandbox.
# Read from the project's .agentbox-env and from AGENTBOX_FORWARD_ENV; the
# values are taken from the current shell, so direnv has already run. Nothing
# is forwarded unless it is named here: most project secrets authenticate to
# services the sandbox has no route to anyway, so forwarding them by default
# would be risk without benefit.
collect_forward_env() {
    local project="$1" name file="$1/.agentbox-env"
    FORWARD_ENV=()
    FORWARD_NAMES=()
    local names=""
    [ -f "$file" ] && names="$(sed -e 's/#.*//' "$file")"
    names="$names ${AGENTBOX_FORWARD_ENV:-}"
    for name in $names; do
        case "$name" in
            [A-Za-z_]*) ;;
            *) die "not a valid environment variable name: $name" ;;
        esac
        case "$name" in
            *[!A-Za-z0-9_]*) die "not a valid environment variable name: $name" ;;
        esac
        if [ -n "${!name+set}" ]; then
            FORWARD_ENV+=(--env "$name")
            FORWARD_NAMES+=("$name")
        else
            info "note: $name is named for forwarding but unset in this shell"
        fi
    done
}

cmd_vendor() {
    local lock="$DIR/vendor.lock" dest="$DIR/vendor"
    mkdir -p "$dest"
    local sum name url have
    while read -r sum name url; do
        case "$sum" in \#*|"") continue ;; esac
        if [ -f "$dest/$name" ]; then
            have="$(shasum -a 256 "$dest/$name" | awk '{print $1}')"
            [ "$have" = "$sum" ] && continue
            info "$name checksum changed, refetching"
        fi
        info "fetching $name"
        curl -4fsSL --retry 3 --max-time 300 -o "$dest/$name" "$url" \
            || die "could not fetch $url"
        have="$(shasum -a 256 "$dest/$name" | awk '{print $1}')"
        [ "$have" = "$sum" ] || die "checksum mismatch for $name
  expected $sum
  got      $have
  If you bumped the version, update vendor.lock deliberately."
    done < "$lock"

    # ponytail ships Agent Skills, which pi loads from its config directory.
    # That directory is a mount, so they cannot be baked into the image --
    # unpack them here from the pinned tarball instead.
    rm -rf "$DIR/pi/skills"
    mkdir -p "$DIR/pi/skills"
    tar -xzf "$dest/ponytail.tgz" -C "$DIR/pi/skills" --strip-components=2 package/skills
    info "vendor/ verified against vendor.lock; ponytail skills unpacked"
}

cmd_build() {
    cmd_vendor
    proxy_start
    info "building $IMAGE"
    container build \
        --dns "$BUILD_DNS" \
        --build-arg "http_proxy=http://$BUILD_GATEWAY:$PROXY_PORT" \
        --build-arg "https_proxy=http://$BUILD_GATEWAY:$PROXY_PORT" \
        --tag "$IMAGE" --file "$DIR/Containerfile" "$@" "$DIR"
}

cmd_run() {
    # agentbox's own flags are consumed here; everything after them goes to pi.
    local env_file=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --env-file) env_file="${2-}"; [ -n "$env_file" ] || die "--env-file needs a path"; shift 2 ;;
            *) break ;;
        esac
    done

    local project="${AGENTBOX_PROJECT:-$PWD}"
    [ -d "$project" ] || die "project directory does not exist: $project"
    project="$(cd "$project" && pwd)"

    container image inspect "$IMAGE" >/dev/null 2>&1 \
        || die "image $IMAGE not built. Run: agentbox build"

    ensure_network
    proxy_start
    local gw; gw="$(gateway)"
    [ -n "$gw" ] || die "could not determine gateway for network $NETWORK"

    # Resolved here, on the host. Passed by name so the value never appears in
    # the container's argv or in the image.
    if [ -z "${OPENCODE_API_KEY:-}" ] && command -v op >/dev/null 2>&1; then
        OPENCODE_API_KEY="$(op read "$OP_REF" 2>/dev/null || true)"
    fi
    [ -n "${OPENCODE_API_KEY:-}" ] || info "warning: OPENCODE_API_KEY is empty (set it, or store it at $OP_REF)"
    export OPENCODE_API_KEY

    # Only supply defaults when the caller has not chosen for themselves.
    local defaults=()
    case " $* " in
        *" --provider "*|*" --model "*) ;;
        *) [ -n "$PROVIDER" ] && defaults=(--provider "$PROVIDER" --model "$MODEL") ;;
    esac

    # pi keys its session store by working directory, which is always
    # /workspace inside the container -- so without a per-project directory
    # every project would share one history and --continue would resume the
    # wrong one. Key it by the real host path instead.
    local slug sessions
    slug="$(basename "$project")-$(printf '%s' "$project" | shasum -a 256 | cut -c1-8)"
    sessions="$STATE/sessions/$slug"
    mkdir -p "$sessions"
    if [ -n "$PROVIDER" ]; then
        case " $* " in
            *" --session-dir "*|*" --no-session "*) ;;
            *) defaults+=(--session-dir /home/box/.pi/sessions) ;;
        esac
    fi

    collect_forward_env "$project"
    local env_file_flag=()
    if [ -n "$env_file" ]; then
        [ -f "$env_file" ] || die "--env-file: not a readable file: $env_file"
        # Unlike the name allowlist this forwards everything in the file.
        env_file_flag=(--env-file "$env_file")
        info "forwarding every variable in $env_file"
    fi
    [ ${#FORWARD_NAMES[@]} -eq 0 ] || info "forwarding: ${FORWARD_NAMES[*]}"

    info "workspace: $project"
    # --no-dns is deliberate: with an allowlisting proxy the container resolves
    # nothing itself, so a missing resolver is one less thing to reach.
    # Allocate a TTY only when there is one; without this the sandbox cannot
    # be driven from a script or a pipe.
    local tty_flags=(--interactive)
    [ -t 0 ] && [ -t 1 ] && tty_flags+=(--tty)

    container run --rm "${tty_flags[@]}" \
        --name "agentbox-$$" \
        "${RUN_FLAGS[@]}" \
        --network "$NETWORK" \
        --no-dns \
        --cpus "$CPUS" --memory "$MEMORY" \
        --cap-drop ALL \
        --volume "$DIR/pi:/home/box/.pi/agent" \
        --volume "$project:/workspace" \
        --volume "$sessions:/home/box/.pi/sessions" \
        --workdir /workspace \
        --env HTTPS_PROXY="http://$gw:$PROXY_PORT" \
        --env HTTP_PROXY="http://$gw:$PROXY_PORT" \
        --env ALL_PROXY="http://$gw:$PROXY_PORT" \
        --env NO_PROXY="localhost,127.0.0.1" \
        --env TERM --env COLORTERM \
        --env OPENCODE_API_KEY \
        "${FORWARD_ENV[@]}" "${env_file_flag[@]}" \
        "$IMAGE" \
        "${defaults[@]}" "$@"
}

# A plain shell in the same sandbox: same mounts, same egress rules, no pi.
cmd_shell() {
    RUN_FLAGS=(--entrypoint /bin/bash)
    PROVIDER="" MODEL=""
    cmd_run "$@"
}

cmd_doctor() {
    printf '%-22s %s\n' "container CLI:" "$(container --version 2>&1 | head -1)"
    printf '%-22s %s\n' "runtime:" "$(container system status 2>&1 | awk '/^status/{print $2}')"
    printf '%-22s %s\n' "image $IMAGE:" "$(container image inspect "$IMAGE" >/dev/null 2>&1 && echo present || echo MISSING)"
    printf '%-22s %s\n' "network $NETWORK:" "$(container network inspect "$NETWORK" >/dev/null 2>&1 && echo "present (gw $(gateway))" || echo MISSING)"
    printf '%-22s %s\n' "squid binary:" "$(command -v squid || echo MISSING)"
    printf '%-22s %s\n' "proxy:" "$(port_answers && echo "answering on :$PROXY_PORT" || echo "not answering")"
    printf '%-22s %s\n' "allowlist entries:" "$(grep -cv '^[[:space:]]*\(#\|$\)' "$DIR/proxy/allowlist.txt")"
    printf '%-22s %s\n' "egress log:" "$LOGFILE"
    printf '%-22s %s\n' "opencode key:" "$([ -n "${OPENCODE_API_KEY:-}" ] && echo "set in env" || echo "not in env (will try $OP_REF)")"
}

cmd_clean() {
    proxy_stop || true
    container network delete "$NETWORK" >/dev/null 2>&1 && info "network removed" || true
    container image delete "$IMAGE" >/dev/null 2>&1 && info "image removed" || true
}

usage() {
    cat <<'USAGE'
usage: agentbox <command> [args]

  build [--no-cache]   Verify vendor/ against vendor.lock, then build the image
  vendor               Fetch and checksum the pinned build artifacts
  run [--env-file F] [pi args...]
                       Run pi in $PWD (override with AGENTBOX_PROJECT)
  shell                Drop into bash in the sandbox instead of pi
  proxy start|stop|status|log
                       Manage the host-side egress proxy
  doctor               Show the state of every moving part
  clean                Stop the proxy, remove the network and image

Egress is default-deny. Edit proxy/allowlist.txt to permit a host, then
`agentbox proxy stop && agentbox proxy start` to reload.
USAGE
}

case "${1-}" in
    build)  shift; cmd_build "$@" ;;
    vendor) cmd_vendor ;;
    run)    shift; cmd_run "$@" ;;
    shell)  shift; cmd_shell "$@" ;;
    doctor) cmd_doctor ;;
    clean)  cmd_clean ;;
    proxy)
        case "${2-}" in
            start)  proxy_start ;;
            stop)   proxy_stop ;;
            status) proxy_running && echo "running (pid $(cat "$PIDFILE"))" || echo "stopped" ;;
            log)    shift 2; tail "${@:--n20}" "$LOGFILE" ;;
            *)      die "usage: agentbox proxy start|stop|status|log" ;;
        esac ;;
    ""|-h|--help|help) usage ;;
    *) die "unknown command: $1 (try --help)" ;;
esac
