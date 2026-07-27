#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$TEST_DIR/.." && pwd)"

[[ "$(uname -s)" == "Darwin" ]] || {
    printf 'SKIP: remote-ssh installer is macOS-only\n'
    exit 0
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/remote-ssh-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

TEST_DOTFILES="$WORK_DIR/dotfiles"
TEST_REMOTE_SSH="$TEST_DOTFILES/setup/macos/remote-ssh"
TEST_KEYS="$TEST_DOTFILES/ssh/authorized_keys"
mkdir -p "$TEST_DOTFILES/setup/macos" "$TEST_KEYS"
cp -R "$SOURCE_DIR" "$TEST_REMOTE_SSH"
chmod +x \
    "$TEST_REMOTE_SSH/tests/bin/rm" \
    "$TEST_REMOTE_SSH/tests/bin/tailscale"

for client_id in iphone macbook macmini; do
    ssh-keygen \
        -q \
        -t ed25519 \
        -N "" \
        -C "$client_id-test" \
        -f "$TEST_KEYS/$client_id"
done

run_success_case() {
    local fixture="$1"
    local expected_sources="$2"
    local first_client_id="$3"
    local first_client_ip="$4"
    local second_client_id="$5"
    local second_client_ip="$6"
    local self_client_id="$7"
    local output_file
    output_file="$WORK_DIR/$(basename "$fixture").out"
    local render_root
    render_root="$WORK_DIR/render-$(basename "$fixture" .json)"
    mkdir "$render_root"

    PATH="$TEST_REMOTE_SSH/tests/bin:$PATH" \
        TMPDIR="$render_root" \
        REMOTE_SSH_TEST_STATUS="$fixture" \
        /bin/bash "$TEST_REMOTE_SSH/install.sh" --dry-run >"$output_file"

    grep -Fqx \
        "[remote-ssh] validated remote SSH sources: $expected_sources" \
        "$output_file"
    grep -Fqx \
        "[remote-ssh] dry-run complete; no files or system settings changed" \
        "$output_file"

    local rendered_keys
    rendered_keys="$(
        find "$render_root" \
            -path '*/dotfiles-remote-ssh.*/tailnet-clients' \
            -type f \
            -print
    )"
    [[ -n "$rendered_keys" && "$rendered_keys" != *$'\n'* ]]
    [[ "$(wc -l <"$rendered_keys" | tr -d ' ')" == "2" ]]

    local restrictions
    restrictions='no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-user-rc'
    grep -Fqx \
        "from=\"$first_client_ip/32\",$restrictions $(<"$TEST_KEYS/$first_client_id.pub")" \
        "$rendered_keys"
    grep -Fqx \
        "from=\"$second_client_ip/32\",$restrictions $(<"$TEST_KEYS/$second_client_id.pub")" \
        "$rendered_keys"

    local self_key_blob
    self_key_blob="$(awk '{ print $2 }' "$TEST_KEYS/$self_client_id.pub")"
    ! grep -Fq "$self_key_blob" "$rendered_keys"
}

run_success_case \
    "$TEST_DIR/fixtures/status-macbook.json" \
    "100.124.94.54 100.102.117.11" \
    iphone 100.124.94.54 \
    macmini 100.102.117.11 \
    macbook
run_success_case \
    "$TEST_DIR/fixtures/status-macmini.json" \
    "100.124.94.54 100.117.55.61" \
    iphone 100.124.94.54 \
    macbook 100.117.55.61 \
    macmini

cp "$TEST_KEYS/iphone.pub" "$TEST_KEYS/macbook.pub"
mkdir "$WORK_DIR/render-duplicate"
if PATH="$TEST_REMOTE_SSH/tests/bin:$PATH" \
    TMPDIR="$WORK_DIR/render-duplicate" \
    REMOTE_SSH_TEST_STATUS="$TEST_DIR/fixtures/status-macbook.json" \
    /bin/bash "$TEST_REMOTE_SSH/install.sh" --dry-run \
    >"$WORK_DIR/duplicate.out" 2>&1; then
    printf 'FAIL: duplicate public key was accepted\n' >&2
    exit 1
fi
grep -Fq "duplicates another enrolled device" "$WORK_DIR/duplicate.out"

printf 'PASS: remote-ssh installer tests\n'
