#!/usr/bin/env bash
# Child shell programs intentionally expand their variables after launch.
# shellcheck disable=SC2016
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$TEST_DIR/../.." && pwd)"
BASH_BIN="$BASH"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bash-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

TEST_HOME="$WORK_DIR/home"
TEST_DOTFILES="$TEST_HOME/.config"
mkdir -p "$TEST_DOTFILES/setup" "$TEST_HOME/.local/bin" "$WORK_DIR/cwd"
cp -R "$SOURCE_DIR/bash" "$TEST_DOTFILES/bash"
cat >"$TEST_DOTFILES/setup/profile" <<'EOF'
DOTFILES_PROFILE=server
DOTFILES_FEAT_STARSHIP=0
DOTFILES_FEAT_DIRENV=0
DOTFILES_FEAT_SMARTCLI=0
DOTFILES_FEAT_R=0
DOTFILES_FEAT_CLAUDE=0
DOTFILES_FEAT_REMOTE_SSH=0
EOF

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# Never touch the real SSH agent, 1Password session, or tmux server.
cat >"$TEST_HOME/.local/bin/ssh-add" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$TEST_HOME/.local/bin/tmux" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$TEST_TMUX_LOG"
EOF
cat >"$TEST_HOME/.local/bin/op" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"$TEST_OP_ARGS"
[[ "$1" == run ]] || exit 91
shift
while (( $# )); do
    case "$1" in
        --env-file=*) cat -- "${1#--env-file=}" >"$TEST_OP_ENV" ;;
        --) shift; break ;;
    esac
    shift
done
"$@"
EOF
chmod +x "$TEST_HOME/.local/bin/ssh-add" "$TEST_HOME/.local/bin/tmux" "$TEST_HOME/.local/bin/op"

clean_bash() {
    env -i \
        HOME="$TEST_HOME" \
        USER=dotfiles-test \
        SHELL="$BASH_BIN" \
        PATH="$TEST_HOME/.local/bin:/usr/bin:/bin" \
        TERM=xterm-256color \
        DOTFILES_DIR="$TEST_DOTFILES" \
        XDG_CONFIG_HOME="$TEST_DOTFILES" \
        TEST_TMUX_LOG="$WORK_DIR/tmux.log" \
        TEST_OP_ARGS="$WORK_DIR/op.args" \
        TEST_OP_ENV="$WORK_DIR/op.env" \
        TEST_WORK_DIR="$WORK_DIR" \
        TEST_SENTINEL=preserved \
        "$BASH_BIN" "$@"
}

# Use the same generated home entrypoints as setup, without applying setup.
# shellcheck source=../lib/common.sh
source "$SOURCE_DIR/setup/lib/common.sh"
bootstrap_bash_profile_content "$TEST_DOTFILES" "$TEST_DOTFILES" server >"$TEST_HOME/.bash_profile"
bootstrap_bashrc_content "$TEST_DOTFILES" "$TEST_DOTFILES" server >"$TEST_HOME/.bashrc"

cd "$WORK_DIR/cwd"

clean_bash --noprofile --norc -c '
    source "$DOTFILES_DIR/bash/env.bash"
    first_path=$PATH
    source "$DOTFILES_DIR/bash/env.bash"
    [[ $PATH == "$first_path" && $TEST_SENTINEL == preserved ]] || exit 1
    [[ $BUN_INSTALL == "$HOME/.local/share/bun" ]] || exit 2
    [[ $CARGO_HOME == "$HOME/.local/share/cargo" ]] || exit 3
    [[ $RUSTUP_HOME == "$HOME/.local/share/rustup" ]] || exit 4
    [[ $UV_CACHE_DIR == /tmp/uv-cache && $PINFOLD_PROFILE == full ]] || exit 5
    for expected in "$HOME/.local/bin" "$BUN_INSTALL/bin" "$CARGO_HOME/bin"; do
        count=0
        IFS=: read -r -a parts <<< "$PATH"
        for part in "${parts[@]}"; do
            [[ $part != "$expected" ]] || ((count+=1))
        done
        [[ $count == 1 ]] || exit 6
    done
' || fail 'environment values or repeated PATH initialization'

output="$(clean_bash --noprofile --norc -c '
    source "$HOME/.bashrc"
    [[ $BUN_INSTALL == "$HOME/.local/share/bun" ]] || exit 1
    ! declare -F oprun >/dev/null || exit 2
    [[ $- != *i* ]] || exit 3
')" || fail 'noninteractive bashrc must load environment only'
[[ -z "$output" ]] || fail 'noninteractive bashrc printed output'

output="$(clean_bash --login -c '
    [[ $BUN_INSTALL == "$HOME/.local/share/bun" ]] || exit 1
    [[ $TEST_SENTINEL == preserved ]] || exit 2
    ! declare -F oprun >/dev/null || exit 3
')" || fail 'noninteractive login startup'
[[ -z "$output" ]] || fail 'noninteractive login startup printed output'

for mode in nonlogin login; do
    args=(--noprofile -i)
    [[ "$mode" != login ]] || args=(--login -i)
    clean_bash "${args[@]}" -c '
        [[ $BUN_INSTALL == "$HOME/.local/share/bun" ]] || exit 1
        declare -F oprun >/dev/null || exit 2
        [[ $TEST_SENTINEL == preserved ]] || exit 3
    ' >"$WORK_DIR/interactive-$mode.out" 2>"$WORK_DIR/interactive-$mode.err" ||
        fail "interactive $mode startup (see startup diagnostics by rerunning manually)"
done

clean_bash --noprofile -i -c '
    source "$HOME/.bashrc"
    source "$HOME/.bashrc"
    for expected in _dotfiles_history_sync _dotfiles_reset_mouse; do
        count=0
        for hook in "${PROMPT_COMMAND[@]}"; do
            [[ $hook != "$expected" ]] || ((count+=1))
        done
        [[ $count == 1 ]] || exit 1
    done
    false
    _dotfiles_history_sync
    hook_status=$?
    [[ $hook_status == 1 ]] || exit 2
' >"$WORK_DIR/hooks.out" 2>"$WORK_DIR/hooks.err" || fail 'repeated bashrc or history hook exit status'

# Both processes use only the temporary history file. bash -i -c does not load
# history before its command, so explicitly exercise the hook in both sessions.
if ! clean_bash --noprofile -i -c '
    history -c
    history -s dotfiles-history-first
    _dotfiles_history_sync
    "$SHELL" --noprofile -i -c "
        _dotfiles_history_sync
        [[ \$(history) == *dotfiles-history-first* ]] || { printf \"child did not load first entry\\n\" >&2; exit 1; }
        history -s dotfiles-history-second
        _dotfiles_history_sync
    " || exit 1
    _dotfiles_history_sync
    [[ $(history) == *dotfiles-history-second* ]] || { printf "parent did not import second entry\n" >&2; exit 2; }
    erase_history
    [[ -z $(history) && ! -s $HISTFILE ]] || { printf "history erasure left entries\n" >&2; exit 3; }
' >"$WORK_DIR/history.out" 2>"$WORK_DIR/history.err"; then
    command cat "$WORK_DIR/history.err" >&2
    fail 'temporary session history synchronization or erasure'
fi

# op records references, not real secrets. Verify argv boundaries and source
# order before allowing the stub to execute a harmless child.
printf 'TOKEN=op://dummy/first/value\n' >"$WORK_DIR/first template.env"
printf 'TOKEN=op://dummy/last/value\n' >"$WORK_DIR/last.env"
clean_bash --noprofile --norc -c '
    source "$DOTFILES_DIR/bash/conf.d/secrets.bash"
    printf -v OP_RUN_LAZY "f\t%s\nr\tTOKEN=op://dummy/middle/value\nf\t%s" "$TEST_WORK_DIR/first template.env" "$TEST_WORK_DIR/last.env"
    export OP_RUN_LAZY
    oprun --no-masking -- /usr/bin/printf "%s\n" "argument with spaces" -- command-flag
' >"$WORK_DIR/child.out" || fail 'oprun with flags and explicit separator'
printf 'argument with spaces\n--\ncommand-flag\n' >"$WORK_DIR/child.expected"
cmp -s "$WORK_DIR/child.expected" "$WORK_DIR/child.out" || fail 'oprun changed child arguments'
printf 'TOKEN=op://dummy/first/value\nTOKEN=op://dummy/middle/value\nTOKEN=op://dummy/last/value\n' >"$WORK_DIR/env.expected"
# Empty separators are harmless dotenv whitespace; compare meaningful lines.
sed '/^$/d' "$WORK_DIR/op.env" >"$WORK_DIR/env.actual"
cmp -s "$WORK_DIR/env.expected" "$WORK_DIR/env.actual" || fail 'oprun changed source ordering'
[[ "$(sed -n '1p' "$WORK_DIR/op.args")" == run ]] || fail 'oprun omitted run subcommand'
[[ "$(sed -n '2p' "$WORK_DIR/op.args")" == --no-masking ]] || fail 'oprun omitted op flag'

clean_bash --noprofile --norc -c '
    source "$DOTFILES_DIR/bash/conf.d/secrets.bash"
    printf -v OP_RUN_LAZY "r\tTOKEN=op://dummy/value/field"
    export OP_RUN_LAZY
    oprun /usr/bin/printf "%s\n" -- child-flag
' >"$WORK_DIR/child.out" || fail 'oprun without explicit separator'
printf '%s\n' -- child-flag >"$WORK_DIR/child.expected"
cmp -s "$WORK_DIR/child.expected" "$WORK_DIR/child.out" || fail 'oprun consumed a child separator'

set +e
clean_bash --noprofile --norc -c '
    source "$DOTFILES_DIR/bash/conf.d/secrets.bash"
    printf -v OP_RUN_LAZY "r\tTOKEN=op://dummy/value/field"
    export OP_RUN_LAZY
    oprun /bin/sh -c "exit 37"
'
child_status=$?
set -e
[[ "$child_status" == 37 ]] || fail 'oprun lost child exit status'

for invalid in missing directory; do
    rm -f "$WORK_DIR/op.args"
    [[ "$invalid" != directory ]] || mkdir "$WORK_DIR/invalid-template"
    clean_bash --noprofile --norc -c '
        source "$DOTFILES_DIR/bash/conf.d/secrets.bash"
        printf -v OP_RUN_LAZY "r\tTOKEN=op://dummy/value/field\nf\t%s" "$TEST_WORK_DIR/invalid-template"
        export OP_RUN_LAZY
        if oprun /usr/bin/touch "$TEST_WORK_DIR/should-not-exist"; then exit 1; fi
        [[ ! -e $TEST_OP_ARGS && ! -e $TEST_WORK_DIR/should-not-exist ]]
    ' >"$WORK_DIR/invalid.out" 2>&1 || fail "oprun accepted $invalid template or invoked op"
done

# Simulated SSH context tests only startup guards. They do not prove sshd or
# actual persistent-session behavior on another host.
for scenario in local ssh bypass existing-tmux dumb no-tty noninteractive; do
    rm -f "$WORK_DIR/tmux.log"
    clean_bash --noprofile --norc -c '
        scenario=$1
        export SSH_CONNECTION="192.0.2.1 1 192.0.2.2 22" SSH_TTY=/dev/test-tty
        case "$scenario" in
            local) unset SSH_CONNECTION SSH_TTY ;;
            bypass) export DOTFILES_NO_AUTO_TMUX=1 ;;
            existing-tmux) export TMUX=test-session ;;
            dumb) export TERM=dumb ;;
            no-tty) unset SSH_TTY ;;
        esac
        if [[ $scenario == noninteractive ]]; then
            source "$HOME/.bashrc"
        else
            exec "$SHELL" --noprofile -i -c :
        fi
    ' test "$scenario" >"$WORK_DIR/tmux-$scenario.out" 2>"$WORK_DIR/tmux-$scenario.err" ||
        fail "tmux guard $scenario"
    if [[ "$scenario" == ssh && "$(uname -s)" == Darwin ]]; then
        printf 'new-session\n-A\n-s\nmain\n' >"$WORK_DIR/tmux.expected"
        cmp -s "$WORK_DIR/tmux.expected" "$WORK_DIR/tmux.log" || fail 'interactive SSH did not attach to main'
    else
        [[ ! -e "$WORK_DIR/tmux.log" ]] || fail "tmux attached during $scenario"
    fi
done

QUOTED_HOME="$WORK_DIR/home with spaces \$literal"
QUOTED_DOTFILES="$QUOTED_HOME/config \$literal"
mkdir -p "$QUOTED_DOTFILES"
cp -R "$SOURCE_DIR/bash" "$QUOTED_DOTFILES/bash"
bootstrap_bash_profile_content "$QUOTED_DOTFILES" "$QUOTED_DOTFILES" server >"$QUOTED_HOME/.bash_profile"
bootstrap_bashrc_content "$QUOTED_DOTFILES" "$QUOTED_DOTFILES" server >"$QUOTED_HOME/.bashrc"
env -i HOME="$QUOTED_HOME" PATH=/usr/bin:/bin \
    EXPECTED_DOTFILES="$QUOTED_DOTFILES" \
    "$BASH_BIN" --login -c '
        [[ $DOTFILES_DIR == "$EXPECTED_DOTFILES" ]] || exit 1
        [[ $XDG_CONFIG_HOME == "$EXPECTED_DOTFILES" ]] || exit 2
        [[ $BUN_INSTALL == "$HOME/.local/share/bun" ]] || exit 3
    ' || fail 'generated startup did not preserve spaces and literal dollar characters'

# Exercise the installed integrations together when available. A temporary
# profile and directory prevent project direnv files and host overrides loading.
integration_tools=1
for tool in starship direnv zoxide fzf; do
    command -v "$tool" >/dev/null 2>&1 || integration_tools=0
done
if (( integration_tools )); then
    cat >>"$TEST_DOTFILES/setup/profile" <<'EOF'
DOTFILES_FEAT_STARSHIP=1
DOTFILES_FEAT_DIRENV=1
DOTFILES_FEAT_SMARTCLI=1
EOF
    rm -f "$WORK_DIR/op.args"
    if ! clean_bash --noprofile -i -c '
        declare -F starship_precmd >/dev/null || exit 1
        [[ $STARSHIP_PROMPT_COMMAND == *_direnv_hook* ]] || exit 2
        [[ $STARSHIP_PROMPT_COMMAND == *__zoxide_hook* ]] || exit 3
        [[ $STARSHIP_PROMPT_COMMAND == *_dotfiles_history_sync* ]] || exit 4
        false | true
        eval "$PROMPT_COMMAND"
        [[ ${STARSHIP_PIPE_STATUS[*]} == "1 0" && $STARSHIP_CMD_STATUS == 0 ]] || exit 5
        false
        eval "$PROMPT_COMMAND"
        [[ $STARSHIP_CMD_STATUS == 1 ]] || exit 6
        [[ ! -e $TEST_OP_ARGS ]] || exit 7
    ' >"$WORK_DIR/integrations.out" 2>"$WORK_DIR/integrations.err"; then
        command cat "$WORK_DIR/integrations.err" >&2
        fail 'installed prompt integrations lost command or pipeline status'
    fi

    # Ghostty injects its hooks after sourcing our startup files. Test the
    # installed script in that order, rather than just testing Starship alone.
    ghostty_script=/Applications/Ghostty.app/Contents/Resources/ghostty/shell-integration/bash/ghostty.bash
    if [[ -r "$ghostty_script" ]]; then
        if ! clean_bash --noprofile --norc -i -c '
            GHOSTTY_BASH_INJECT=1
            source "$1"
            [[ $(declare -p PROMPT_COMMAND) == "declare -a"* ]] || exit 1
            [[ ${PROMPT_COMMAND[0]} == starship_precmd ]] || exit 2
            [[ ${PROMPT_COMMAND[1]} == *__ghostty_hook* ]] || exit 3
            false | true
            eval "${PROMPT_COMMAND[0]}"
            [[ ${STARSHIP_PIPE_STATUS[*]} == "1 0" && $STARSHIP_CMD_STATUS == 0 ]] || exit 4
            false
            eval "${PROMPT_COMMAND[0]}"
            [[ $STARSHIP_CMD_STATUS == 1 ]] || exit 5
            eval "${PROMPT_COMMAND[1]}"
            [[ ! -e $TEST_OP_ARGS ]] || exit 6
        ' test "$ghostty_script" >"$WORK_DIR/ghostty.out" 2>"$WORK_DIR/ghostty.err"; then
            command cat "$WORK_DIR/ghostty.err" >&2
            fail 'Ghostty injection lost prompt hook order or pipeline status'
        fi
    else
        printf 'SKIP: Ghostty injection test needs the installed macOS application\n'
    fi
else
    printf 'SKIP: combined integration test needs starship, direnv, zoxide, and fzf\n'
fi

printf 'PASS: Bash startup, environment, secret wrapper, and tmux guard tests\n'
