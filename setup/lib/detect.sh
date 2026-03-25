#!/usr/bin/env bash

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "darwin" ;;
        Linux) echo "linux" ;;
        *) echo "unknown" ;;
    esac
}

detect_package_manager() {
    local pm=""
    if command -v brew >/dev/null 2>&1; then
        pm="brew"
    elif command -v apt-get >/dev/null 2>&1; then
        pm="apt"
    elif command -v dnf >/dev/null 2>&1; then
        pm="dnf"
    elif command -v yum >/dev/null 2>&1; then
        pm="yum"
    elif command -v pacman >/dev/null 2>&1; then
        pm="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        pm="zypper"
    elif command -v apk >/dev/null 2>&1; then
        pm="apk"
    fi
    echo "$pm"
}

detect_sudo() {
    local no_sudo="$1"

    if [[ "$no_sudo" -eq 1 ]]; then
        echo "disabled"
        return
    fi

    if [[ "$(id -u)" -eq 0 ]]; then
        echo "root"
        return
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        echo "unavailable"
        return
    fi

    if sudo -n true >/dev/null 2>&1; then
        echo "passwordless"
    else
        echo "requires-password"
    fi
}
