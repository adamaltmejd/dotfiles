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
        -h|--help)
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
PUBLIC_KEY_FILE="$DOTFILES_DIR/ssh/authorized_keys/iphone.pub"
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

if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
    die "missing $PUBLIC_KEY_FILE; export one phone public key there first"
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"
: "${REMOTE_SSH_CLIENT_DNS_NAME:?set REMOTE_SSH_CLIENT_DNS_NAME in $CONFIG_FILE}"

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

CLIENT_MATCH_COUNT="$(
    jq -r --arg dns "$REMOTE_SSH_CLIENT_DNS_NAME" \
        '[.Peer[]? | select(.DNSName == $dns and .OS == "iOS")] | length' \
        <<<"$STATUS_JSON"
)"
[[ "$CLIENT_MATCH_COUNT" == "1" ]] ||
    die "expected one iOS peer named $REMOTE_SSH_CLIENT_DNS_NAME"

CLIENT_TAILSCALE_IPV4="$(
    jq -r --arg dns "$REMOTE_SSH_CLIENT_DNS_NAME" \
        '.Peer[]? |
         select(.DNSName == $dns and .OS == "iOS") |
         .TailscaleIPs[]? |
         select(startswith("100."))' \
        <<<"$STATUS_JSON"
)"
[[ -n "$CLIENT_TAILSCALE_IPV4" && "$CLIENT_TAILSCALE_IPV4" != *$'\n'* ]] ||
    die "expected exactly one Tailscale IPv4 address for the enrolled phone"

if grep -Eq -- '-----BEGIN .*PRIVATE KEY-----' "$PUBLIC_KEY_FILE"; then
    die "$PUBLIC_KEY_FILE contains a private key; remove it immediately"
fi

PUBLIC_KEY_COUNT="$(
    awk 'NF && $1 !~ /^#/ { count++ } END { print count + 0 }' "$PUBLIC_KEY_FILE"
)"
[[ "$PUBLIC_KEY_COUNT" == "1" ]] ||
    die "$PUBLIC_KEY_FILE must contain exactly one non-comment public-key line"

PUBLIC_KEY_LINE="$(awk 'NF && $1 !~ /^#/ { print }' "$PUBLIC_KEY_FILE")"
PUBLIC_KEY_TYPE="${PUBLIC_KEY_LINE%% *}"
case "$PUBLIC_KEY_TYPE" in
    ssh-ed25519|ecdsa-sha2-nistp256|sk-ecdsa-sha2-nistp256@openssh.com|sk-ssh-ed25519@openssh.com)
        ;;
    *)
        die "unsupported phone key type: $PUBLIC_KEY_TYPE"
        ;;
esac
ssh-keygen -lf "$PUBLIC_KEY_FILE" >/dev/null ||
    die "invalid public key: $PUBLIC_KEY_FILE"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-remote-ssh.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

SSHD_RENDERED="$TEMP_DIR/050-tailnet-only.conf"
PF_RENDERED="$TEMP_DIR/local.tailscale-ssh"
AUTHORIZED_KEYS_RENDERED="$TEMP_DIR/iphone"
SSHD_MAIN_VALIDATE="$TEMP_DIR/sshd_config"
SSHD_DROPIN_VALIDATE="$TEMP_DIR/sshd_config.d"
TEMP_HOST_KEY="$TEMP_DIR/ssh_host_ed25519_key"

sed \
    -e "s/__REMOTE_USER__/$REMOTE_USER/g" \
    -e "s/__CLIENT_TAILSCALE_IPV4__/$CLIENT_TAILSCALE_IPV4/g" \
    "$SSHD_TEMPLATE" >"$SSHD_RENDERED"

sed \
    -e "s/__CLIENT_TAILSCALE_IPV4__/$CLIENT_TAILSCALE_IPV4/g" \
    -e "s/__SERVER_TAILSCALE_IPV4__/$SERVER_TAILSCALE_IPV4/g" \
    "$PF_TEMPLATE" >"$PF_RENDERED"

printf '%s %s\n' \
    'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-user-rc' \
    "$PUBLIC_KEY_LINE" >"$AUTHORIZED_KEYS_RENDERED"

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
        "authorizedkeysfile .ssh/authorized_keys.d/iphone" \
        "allowtcpforwarding no" \
        "allowagentforwarding no" \
        "x11forwarding no" \
        "gatewayports no" \
        "permittunnel no" \
        "permituserrc no"; do
        grep -Fqx "$expected_setting" <<<"$effective_config" ||
            die "sshd validation did not produce: $expected_setting"
    done
    grep -Fqx "allowusers $REMOTE_USER@$CLIENT_TAILSCALE_IPV4/32" \
        <<<"$effective_config" ||
        die "sshd validation did not preserve the exact AllowUsers source"
}

SSHD_CONNECTION_SPEC="user=$REMOTE_USER,addr=$CLIENT_TAILSCALE_IPV4,laddr=$SERVER_TAILSCALE_IPV4,lport=22,host=$REMOTE_SSH_CLIENT_DNS_NAME"
SSHD_EFFECTIVE="$(
    /usr/sbin/sshd -T \
        -f "$SSHD_MAIN_VALIDATE" \
        -h "$TEMP_HOST_KEY" \
        -C "$SSHD_CONNECTION_SPEC"
)"
validate_sshd_policy "$SSHD_EFFECTIVE"

/sbin/pfctl -nf "$PF_RENDERED"
grep -Fqx 'anchor "com.apple/*"' /etc/pf.conf ||
    die "/etc/pf.conf does not contain the required com.apple wildcard anchor"
plutil -lint "$PLIST_SOURCE" >/dev/null
bash -n "$PF_DAEMON_SOURCE"

log "validated phone $REMOTE_SSH_CLIENT_DNS_NAME ($CLIENT_TAILSCALE_IPV4)"
log "validated Mac Tailscale address $SERVER_TAILSCALE_IPV4"
log "validated $(ssh-keygen -lf "$PUBLIC_KEY_FILE")"
log "validated sshd, pf, and LaunchDaemon configuration"

if [[ "$MODE" == "dry-run" ]]; then
    log "would install $HOME/.ssh/authorized_keys.d/iphone"
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
    "$HOME/.ssh/authorized_keys.d/iphone" \
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
SSHD_INSTALLED_EFFECTIVE="$(
    sudo /usr/sbin/sshd -T -C "$SSHD_CONNECTION_SPEC"
)"
validate_sshd_policy "$SSHD_INSTALLED_EFFECTIVE"

if sudo launchctl print system/local.pf-tailscale-ssh >/dev/null 2>&1; then
    sudo launchctl bootout system/local.pf-tailscale-ssh
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

log "Remote Login enabled for $REMOTE_USER from $CLIENT_TAILSCALE_IPV4 only"
log "connect to $REMOTE_USER@$SERVER_TAILSCALE_IPV4 on TCP/22"
log "verify this host key before accepting the first connection:"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
