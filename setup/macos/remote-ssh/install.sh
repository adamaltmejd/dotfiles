#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

MODE="dry-run"
BACKUP_DIR="$HOME/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

log() {
    printf '[remote-ssh] %s\n' "$*"
}

warn() {
    printf '[remote-ssh] warning: %s\n' "$*" >&2
}

die() {
    printf '[remote-ssh] error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage: install.sh [--dry-run|--apply] [--backup-dir <path>]

Renders and validates a Tailscale-only macOS SSH server configuration. Apply
mode installs root-owned sshd/pf files, enables the firewalls, and turns on
Remote Login. Dry-run mode makes no system or home-directory changes.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --apply)
            MODE="apply"
            shift
            ;;
        --backup-dir)
            BACKUP_DIR="${2:-}"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "this installer supports macOS only"
[[ "$(id -u)" -ne 0 ]] || die "run as the target user, not as root"
[[ "$BACKUP_DIR" == /* ]] || die "--backup-dir must be an absolute path"

CONFIG_FILE="$SCRIPT_DIR/config"
PUBLIC_KEYS_DIR="$DOTFILES_DIR/ssh/authorized_keys"
SSHD_TEMPLATE="$SCRIPT_DIR/sshd.conf.tmpl"
PF_TEMPLATE="$SCRIPT_DIR/pf-anchor.conf.tmpl"
PLIST_SOURCE="$SCRIPT_DIR/pf-enable.plist"
PF_DAEMON_SOURCE="$SCRIPT_DIR/pf-enable.sh"

for required_file in \
    "$CONFIG_FILE" \
    "$SSHD_TEMPLATE" \
    "$PF_TEMPLATE" \
    "$PLIST_SOURCE" \
    "$PF_DAEMON_SOURCE"; do
    [[ -f "$required_file" ]] || die "missing required file: $required_file"
done

[[ -d "$PUBLIC_KEYS_DIR" ]] ||
    die "missing public-key directory: $PUBLIC_KEYS_DIR"

# shellcheck source=/dev/null
source "$CONFIG_FILE"
declare -p REMOTE_SSH_CLIENTS >/dev/null 2>&1 ||
    die "set REMOTE_SSH_CLIENTS in $CONFIG_FILE"
[[ "${#REMOTE_SSH_CLIENTS[@]}" -ge 2 ]] ||
    die "REMOTE_SSH_CLIENTS must contain at least two devices"

REMOTE_USER="$(id -un)"
[[ "$REMOTE_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] ||
    die "unsupported local username: $REMOTE_USER"

for command_name in jq ssh-keygen; do
    command -v "$command_name" >/dev/null 2>&1 ||
        die "required command not found: $command_name"
done

if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_BIN="$(command -v tailscale)"
elif [[ -x /usr/local/bin/tailscale ]]; then
    TAILSCALE_BIN="/usr/local/bin/tailscale"
else
    die "Tailscale CLI not found; install and sign in to Tailscale first"
fi

STATUS_JSON="$("$TAILSCALE_BIN" status --json)" ||
    die "could not read Tailscale status; ensure Tailscale is running"
[[ "$(jq -r '.BackendState' <<<"$STATUS_JSON")" == "Running" ]] ||
    die "Tailscale is not connected"

SERVER_TAILSCALE_IPV4="$(
    jq -r '.Self.TailscaleIPs[]? | select(startswith("100."))' <<<"$STATUS_JSON"
)"
[[ -n "$SERVER_TAILSCALE_IPV4" && "$SERVER_TAILSCALE_IPV4" != *$'\n'* ]] ||
    die "expected exactly one local Tailscale IPv4 address"

SERVER_TAILSCALE_DNS_NAME="$(jq -r '.Self.DNSName // empty' <<<"$STATUS_JSON")"
[[ -n "$SERVER_TAILSCALE_DNS_NAME" ]] ||
    die "local Tailscale device has no DNS name"

ALLOWED_USER_TOKENS=()
CLIENT_TAILSCALE_IPV4S=()
CLIENT_DNS_NAMES=()
CLIENT_PUBLIC_KEY_LINES=()
ALL_CLIENT_IDS=()
ALL_CLIENT_DNS_NAMES=()
ALL_CLIENT_TAILSCALE_IPV4S=()
SEEN_PUBLIC_KEY_MATERIAL=()
SELF_CLIENT_COUNT=0

for client_record in "${REMOTE_SSH_CLIENTS[@]}"; do
    IFS='|' read -r \
        CLIENT_ID CLIENT_DNS_NAME CLIENT_EXPECTED_OS CLIENT_EXTRA \
        <<<"$client_record"
    [[ -n "$CLIENT_ID" && -n "$CLIENT_DNS_NAME" &&
        -n "$CLIENT_EXPECTED_OS" && -z "$CLIENT_EXTRA" ]] ||
        die "invalid client record: $client_record"
    [[ "$CLIENT_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
        die "invalid client key name: $CLIENT_ID"
    [[ "$CLIENT_DNS_NAME" =~ ^[A-Za-z0-9.-]+\.$ ]] ||
        die "invalid Tailscale DNS name: $CLIENT_DNS_NAME"
    case "$CLIENT_EXPECTED_OS" in
        iOS | macOS) ;;
        *) die "unsupported client OS for $CLIENT_ID: $CLIENT_EXPECTED_OS" ;;
    esac

    CLIENT_MATCH_COUNT="$(
        jq -r \
            --arg dns "$CLIENT_DNS_NAME" \
            --arg os "$CLIENT_EXPECTED_OS" \
            '([.Self] + [.Peer[]?]) |
             map(select(.DNSName == $dns and .OS == $os)) |
             length' \
            <<<"$STATUS_JSON"
    )"
    [[ "$CLIENT_MATCH_COUNT" == "1" ]] ||
        die "expected one $CLIENT_EXPECTED_OS device named $CLIENT_DNS_NAME"

    CLIENT_TAILSCALE_IPV4="$(
        jq -r \
            --arg dns "$CLIENT_DNS_NAME" \
            --arg os "$CLIENT_EXPECTED_OS" \
            '([.Self] + [.Peer[]?])[] |
             select(.DNSName == $dns and .OS == $os) |
             .TailscaleIPs[]? |
             select(startswith("100."))' \
            <<<"$STATUS_JSON"
    )"
    [[ -n "$CLIENT_TAILSCALE_IPV4" &&
        "$CLIENT_TAILSCALE_IPV4" != *$'\n'* ]] ||
        die "expected exactly one Tailscale IPv4 address for $CLIENT_ID"

    PUBLIC_KEY_FILE="$PUBLIC_KEYS_DIR/$CLIENT_ID.pub"
    [[ -f "$PUBLIC_KEY_FILE" ]] ||
        die "missing enrolled public key: $PUBLIC_KEY_FILE"
    if grep -Eq -- '-----BEGIN .*PRIVATE KEY-----' "$PUBLIC_KEY_FILE"; then
        die "$PUBLIC_KEY_FILE contains a private key; remove it immediately"
    fi

    PUBLIC_KEY_COUNT="$(
        awk 'NF && $1 !~ /^#/ { count++ } END { print count + 0 }' \
            "$PUBLIC_KEY_FILE"
    )"
    [[ "$PUBLIC_KEY_COUNT" == "1" ]] ||
        die "$PUBLIC_KEY_FILE must contain exactly one public-key line"

    PUBLIC_KEY_LINE="$(
        awk 'NF && $1 !~ /^#/ { print }' "$PUBLIC_KEY_FILE"
    )"
    read -r PUBLIC_KEY_TYPE PUBLIC_KEY_BLOB _ <<<"$PUBLIC_KEY_LINE"
    case "$PUBLIC_KEY_TYPE" in
        ssh-ed25519 | ecdsa-sha2-nistp256 | sk-ecdsa-sha2-nistp256@openssh.com | sk-ssh-ed25519@openssh.com)
            ;;
        *)
            die "unsupported key type for $CLIENT_ID: $PUBLIC_KEY_TYPE"
            ;;
    esac
    [[ -n "$PUBLIC_KEY_BLOB" ]] ||
        die "missing public-key data in $PUBLIC_KEY_FILE"
    ssh-keygen -lf "$PUBLIC_KEY_FILE" >/dev/null ||
        die "invalid public key: $PUBLIC_KEY_FILE"

    PUBLIC_KEY_MATERIAL="$PUBLIC_KEY_TYPE $PUBLIC_KEY_BLOB"
    if ((${#SEEN_PUBLIC_KEY_MATERIAL[@]} > 0)); then
        for seen_key_material in "${SEEN_PUBLIC_KEY_MATERIAL[@]}"; do
            [[ "$PUBLIC_KEY_MATERIAL" != "$seen_key_material" ]] ||
                die "public key for $CLIENT_ID duplicates another enrolled device"
        done
    fi
    SEEN_PUBLIC_KEY_MATERIAL+=("$PUBLIC_KEY_MATERIAL")

    ALL_CLIENT_IDS+=("$CLIENT_ID")
    ALL_CLIENT_DNS_NAMES+=("$CLIENT_DNS_NAME")
    ALL_CLIENT_TAILSCALE_IPV4S+=("$CLIENT_TAILSCALE_IPV4")

    if [[ "$CLIENT_DNS_NAME" == "$SERVER_TAILSCALE_DNS_NAME" ]]; then
        SELF_CLIENT_COUNT=$((SELF_CLIENT_COUNT + 1))
        continue
    fi

    ALLOWED_USER_TOKENS+=("$REMOTE_USER@$CLIENT_TAILSCALE_IPV4/32")
    CLIENT_TAILSCALE_IPV4S+=("$CLIENT_TAILSCALE_IPV4")
    CLIENT_DNS_NAMES+=("$CLIENT_DNS_NAME")
    CLIENT_PUBLIC_KEY_LINES+=("$PUBLIC_KEY_LINE")
done

[[ "$SELF_CLIENT_COUNT" -eq 1 ]] ||
    die "the local Mac must match exactly one configured client"
[[ "${#CLIENT_TAILSCALE_IPV4S[@]}" -ge 1 ]] ||
    die "no remote SSH clients remain after excluding the local Mac"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-remote-ssh.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

SSHD_RENDERED="$TEMP_DIR/050-tailnet-only.conf"
PF_RENDERED="$TEMP_DIR/local.tailscale-ssh"
AUTHORIZED_KEYS_RENDERED="$TEMP_DIR/tailnet-clients"
SSHD_MAIN_VALIDATE="$TEMP_DIR/sshd_config"
SSHD_DROPIN_VALIDATE="$TEMP_DIR/sshd_config.d"
TEMP_HOST_KEY="$TEMP_DIR/ssh_host_ed25519_key"

ALLOWED_USERS="${ALLOWED_USER_TOKENS[*]}"
CLIENT_IPV4_LIST=""
for client_ip in "${CLIENT_TAILSCALE_IPV4S[@]}"; do
    if [[ -n "$CLIENT_IPV4_LIST" ]]; then
        CLIENT_IPV4_LIST="$CLIENT_IPV4_LIST, "
    fi
    CLIENT_IPV4_LIST="$CLIENT_IPV4_LIST$client_ip"
done

sed \
    -e "s|__ALLOWED_USERS__|$ALLOWED_USERS|g" \
    "$SSHD_TEMPLATE" >"$SSHD_RENDERED"

sed \
    -e "s/__CLIENT_TAILSCALE_IPV4S__/$CLIENT_IPV4_LIST/g" \
    -e "s/__SERVER_TAILSCALE_IPV4__/$SERVER_TAILSCALE_IPV4/g" \
    "$PF_TEMPLATE" >"$PF_RENDERED"

for ((client_index = 0; client_index < ${#CLIENT_TAILSCALE_IPV4S[@]}; client_index++)); do
    printf 'from="%s/32",%s %s\n' \
        "${CLIENT_TAILSCALE_IPV4S[$client_index]}" \
        'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-user-rc' \
        "${CLIENT_PUBLIC_KEY_LINES[$client_index]}" \
        >>"$AUTHORIZED_KEYS_RENDERED"
done

# Mirror the deployed drop-in directory so sshd expands the files in their
# real lexical order. Replacing only our managed filename catches an earlier
# drop-in that would win OpenSSH's first-value option processing.
mkdir "$SSHD_DROPIN_VALIDATE"
for existing_dropin in /etc/ssh/sshd_config.d/*; do
    [[ -e "$existing_dropin" ]] || continue
    [[ -f "$existing_dropin" ]] ||
        die "unsupported sshd drop-in: $existing_dropin"
    if [[ "$(basename "$existing_dropin")" != "050-tailnet-only.conf" ]]; then
        cp "$existing_dropin" "$SSHD_DROPIN_VALIDATE/"
    fi
done
cp "$SSHD_RENDERED" "$SSHD_DROPIN_VALIDATE/050-tailnet-only.conf"

awk -v dropin_glob="$SSHD_DROPIN_VALIDATE/*" '
    !inserted && $0 ~ /^[[:space:]]*Include[[:space:]]+\/etc\/ssh\/sshd_config\.d\/\*/ {
        print "Include " dropin_glob
        inserted = 1
        next
    }
    { print }
    END {
        if (!inserted) {
            exit 42
        }
    }
' /etc/ssh/sshd_config >"$SSHD_MAIN_VALIDATE" ||
    die "could not construct an sshd validation configuration"

ssh-keygen -q -t ed25519 -N "" -f "$TEMP_HOST_KEY"
/usr/sbin/sshd -t \
    -f "$SSHD_MAIN_VALIDATE" \
    -h "$TEMP_HOST_KEY"

validate_sshd_policy() {
    local effective_config="$1"
    local expected_setting
    for expected_setting in \
        "passwordauthentication no" \
        "kbdinteractiveauthentication no" \
        "pubkeyauthentication yes" \
        "authenticationmethods publickey" \
        "permitrootlogin no" \
        "authorizedkeysfile .ssh/authorized_keys.d/tailnet-clients" \
        "allowtcpforwarding no" \
        "allowagentforwarding no" \
        "x11forwarding no" \
        "gatewayports no" \
        "permittunnel no" \
        "permituserrc no"; do
        grep -Fqx "$expected_setting" <<<"$effective_config" ||
            die "sshd validation did not produce: $expected_setting"
    done
    local actual_allow_users
    actual_allow_users="$(
        grep -E '^allowusers[[:space:]]' <<<"$effective_config" || true
    )"
    local actual_allow_user_count
    actual_allow_user_count="$(
        wc -l <<<"$actual_allow_users" | tr -d ' '
    )"
    [[ "$actual_allow_user_count" == "${#ALLOWED_USER_TOKENS[@]}" ]] ||
        die "sshd AllowUsers produced an unexpected number of entries"
    local allowed_user_token
    for allowed_user_token in "${ALLOWED_USER_TOKENS[@]}"; do
        grep -Fqx "allowusers $allowed_user_token" <<<"$actual_allow_users" ||
            die "sshd AllowUsers omitted: $allowed_user_token"
    done
}

SSHD_CONNECTION_SPECS=()
for ((client_index = 0; client_index < ${#CLIENT_TAILSCALE_IPV4S[@]}; client_index++)); do
    SSHD_CONNECTION_SPEC="user=$REMOTE_USER,addr=${CLIENT_TAILSCALE_IPV4S[$client_index]},laddr=$SERVER_TAILSCALE_IPV4,lport=22,host=${CLIENT_DNS_NAMES[$client_index]}"
    SSHD_CONNECTION_SPECS+=("$SSHD_CONNECTION_SPEC")
    SSHD_EFFECTIVE="$(
        /usr/sbin/sshd -T \
            -f "$SSHD_MAIN_VALIDATE" \
            -h "$TEMP_HOST_KEY" \
            -C "$SSHD_CONNECTION_SPEC"
    )"
    validate_sshd_policy "$SSHD_EFFECTIVE"
done

/sbin/pfctl -nf "$PF_RENDERED"
grep -Fqx 'anchor "com.apple/*"' /etc/pf.conf ||
    die "/etc/pf.conf does not contain the required com.apple wildcard anchor"
plutil -lint "$PLIST_SOURCE" >/dev/null
bash -n "$PF_DAEMON_SOURCE"

log "validated local Mac $SERVER_TAILSCALE_DNS_NAME ($SERVER_TAILSCALE_IPV4)"
for ((client_index = 0; client_index < ${#ALL_CLIENT_IDS[@]}; client_index++)); do
    log "validated ${ALL_CLIENT_IDS[$client_index]} ${ALL_CLIENT_DNS_NAMES[$client_index]} (${ALL_CLIENT_TAILSCALE_IPV4S[$client_index]})"
    log "validated $(ssh-keygen -lf "$PUBLIC_KEYS_DIR/${ALL_CLIENT_IDS[$client_index]}.pub")"
done
log "validated remote SSH sources: ${CLIENT_TAILSCALE_IPV4S[*]}"
log "validated sshd, pf, and LaunchDaemon configuration"

if [[ "$MODE" == "dry-run" ]]; then
    log "would install $HOME/.ssh/authorized_keys.d/tailnet-clients"
    log "would install /etc/ssh/sshd_config.d/050-tailnet-only.conf"
    log "would install /etc/pf.anchors/local.tailscale-ssh"
    log "would install the scoped PF daemon and LaunchDaemon"
    log "would enable the application firewall, pf, and Remote Login"
    log "dry-run complete; no files or system settings changed"
    exit 0
fi

mkdir -p "$BACKUP_DIR"

backup_user_file() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    local backup="$BACKUP_DIR/${target#/}"
    mkdir -p "$(dirname "$backup")"
    cp -p "$target" "$backup"
    log "backed up $target to $backup"
}

install_user_file() {
    local source="$1"
    local target="$2"
    local mode="$3"
    if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
        chmod "$mode" "$target"
        log "unchanged $target"
        return
    fi
    backup_user_file "$target"
    install -m "$mode" "$source" "$target"
    log "installed $target"
}

backup_root_file() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    local backup="$BACKUP_DIR/${target#/}"
    mkdir -p "$(dirname "$backup")"
    sudo install \
        -o "$(id -u)" \
        -g "$(id -g)" \
        -m 600 \
        "$target" \
        "$backup"
    log "backed up $target to $backup"
}

install_root_file() {
    local source="$1"
    local target="$2"
    local mode="$3"
    if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
        sudo chown root:wheel "$target"
        sudo chmod "$mode" "$target"
        log "unchanged $target"
        return
    fi
    backup_root_file "$target"
    sudo install -o root -g wheel -m "$mode" "$source" "$target"
    log "installed $target"
}

mkdir -p "$HOME/.ssh/authorized_keys.d"
chmod 700 "$HOME/.ssh" "$HOME/.ssh/authorized_keys.d"
install_user_file \
    "$AUTHORIZED_KEYS_RENDERED" \
    "$HOME/.ssh/authorized_keys.d/tailnet-clients" \
    600

install_root_file \
    "$SSHD_RENDERED" \
    /etc/ssh/sshd_config.d/050-tailnet-only.conf \
    644
install_root_file \
    "$PF_RENDERED" \
    /etc/pf.anchors/local.tailscale-ssh \
    644
install_root_file \
    "$PF_DAEMON_SOURCE" \
    /Library/PrivilegedHelperTools/local.pf-tailscale-ssh \
    755
install_root_file \
    "$PLIST_SOURCE" \
    /Library/LaunchDaemons/local.pf-tailscale-ssh.plist \
    644

sudo ssh-keygen -A
sudo /usr/sbin/sshd -t
for SSHD_CONNECTION_SPEC in "${SSHD_CONNECTION_SPECS[@]}"; do
    SSHD_INSTALLED_EFFECTIVE="$(
        sudo /usr/sbin/sshd -T -C "$SSHD_CONNECTION_SPEC"
    )"
    validate_sshd_policy "$SSHD_INSTALLED_EFFECTIVE"
done

LEGACY_AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys.d/iphone"
if [[ -e "$LEGACY_AUTHORIZED_KEYS" || -L "$LEGACY_AUTHORIZED_KEYS" ]]; then
    backup_user_file "$LEGACY_AUTHORIZED_KEYS"
    rm "$LEGACY_AUTHORIZED_KEYS"
    log "removed obsolete managed file $LEGACY_AUTHORIZED_KEYS"
fi

PF_SERVICE_LABEL="system/local.pf-tailscale-ssh"
if sudo launchctl print "$PF_SERVICE_LABEL" >/dev/null 2>&1; then
    sudo launchctl bootout "$PF_SERVICE_LABEL"

    PF_UNLOADED=0
    for _ in {1..20}; do
        if ! sudo launchctl print "$PF_SERVICE_LABEL" >/dev/null 2>&1; then
            PF_UNLOADED=1
            break
        fi
        sleep 0.25
    done
    [[ "$PF_UNLOADED" -eq 1 ]] ||
        die "the previous PF service instance did not finish unloading"
fi
sudo launchctl bootstrap \
    system \
    /Library/LaunchDaemons/local.pf-tailscale-ssh.plist

PF_READY=0
for _ in {1..20}; do
    if sudo /sbin/pfctl -s info 2>/dev/null |
        grep -Fq "Status: Enabled" &&
        [[ -n "$(
            sudo /sbin/pfctl \
                -a com.apple/local.tailscale-ssh \
                -sr 2>/dev/null
        )" ]]; then
        PF_READY=1
        break
    fi
    sleep 0.25
done
[[ "$PF_READY" -eq 1 ]] ||
    die "the PF service did not enable PF and load its scoped anchor"

FIREWALL="/usr/libexec/ApplicationFirewall/socketfilterfw"
sudo "$FIREWALL" --setglobalstate on
sudo "$FIREWALL" --setblockall off
sudo "$FIREWALL" --setallowsigned on
sudo "$FIREWALL" --setallowsignedapp off
sudo "$FIREWALL" --setstealthmode on
sudo "$FIREWALL" --add /usr/libexec/sshd-keygen-wrapper >/dev/null
sudo "$FIREWALL" --unblockapp /usr/libexec/sshd-keygen-wrapper >/dev/null

if ! REMOTE_LOGIN_SET_OUTPUT="$(
    sudo /usr/sbin/systemsetup -setremotelogin on 2>&1
)"; then
    warn "$REMOTE_LOGIN_SET_OUTPUT"
    die "configuration is installed safely, but Remote Login could not be enabled; grant Terminal Full Disk Access and rerun"
fi

if ! REMOTE_LOGIN_STATE_OUTPUT="$(
    sudo /usr/sbin/systemsetup -getremotelogin 2>&1
)"; then
    warn "$REMOTE_LOGIN_STATE_OUTPUT"
    die "configuration is installed safely, but Remote Login state could not be verified"
fi

if ! grep -Fqx "Remote Login: On" <<<"$REMOTE_LOGIN_STATE_OUTPUT"; then
    warn "systemsetup -setremotelogin output: ${REMOTE_LOGIN_SET_OUTPUT:-<none>}"
    warn "systemsetup -getremotelogin output: ${REMOTE_LOGIN_STATE_OUTPUT:-<none>}"
    die "configuration is installed safely, but Remote Login is not enabled; grant Terminal Full Disk Access and rerun"
fi

log "Remote Login enabled for $REMOTE_USER from: ${CLIENT_TAILSCALE_IPV4S[*]}"
log "connect to $REMOTE_USER@${SERVER_TAILSCALE_DNS_NAME%.} on TCP/22"
log "verify this host key before accepting the first connection:"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
