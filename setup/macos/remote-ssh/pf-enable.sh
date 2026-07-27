#!/bin/bash
set -euo pipefail

PFCTL="/sbin/pfctl"
ANCHOR_NAME="com.apple/local.tailscale-ssh"
RULES_FILE="/etc/pf.anchors/local.tailscale-ssh"
TOKEN_FILE="/var/run/local.pf-tailscale-ssh.token"
ENABLE_TOKEN=""

release_enable_reference() {
    if [[ -n "$ENABLE_TOKEN" ]]; then
        "$PFCTL" -X "$ENABLE_TOKEN" >/dev/null 2>&1 || true
        ENABLE_TOKEN=""
    fi
    rm -f "$TOKEN_FILE"
}

terminate() {
    exit 0
}

trap release_enable_reference EXIT
trap terminate HUP INT TERM

# A SIGKILL cannot run the exit trap. Release any token recorded by the
# previous launchd instance before acquiring a replacement.
if [[ -f "$TOKEN_FILE" ]]; then
    STALE_TOKEN="$(<"$TOKEN_FILE")"
    if [[ "$STALE_TOKEN" =~ ^[0-9]+$ ]]; then
        "$PFCTL" -X "$STALE_TOKEN" >/dev/null 2>&1 || true
    fi
    rm -f "$TOKEN_FILE"
fi

"$PFCTL" -nf "$RULES_FILE"
ENABLE_OUTPUT="$("$PFCTL" -E 2>&1)"
ENABLE_TOKEN="$(
    awk '$1 == "Token" && $2 == ":" { print $3 }' <<<"$ENABLE_OUTPUT"
)"
if [[ ! "$ENABLE_TOKEN" =~ ^[0-9]+$ ]]; then
    printf 'Could not obtain a PF enable-reference token:\n%s\n' \
        "$ENABLE_OUTPUT" >&2
    exit 1
fi
umask 077
printf '%s\n' "$ENABLE_TOKEN" >"$TOKEN_FILE"

"$PFCTL" -a "$ANCHOR_NAME" -f "$RULES_FILE"

# Keep the process, and therefore ownership of the enable reference, alive.
while true; do
    sleep 86400 &
    wait "$!" || true
done
