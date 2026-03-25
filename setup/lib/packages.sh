#!/usr/bin/env bash

read_package_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }
    ' "$file"
}

# Run a command, prepending sudo when the host requires it.
# Brew and apk (typically root in containers) are handled separately.
_pkg_run() {
    local sudo_mode="$1"; shift
    case "$sudo_mode" in
        disabled)
            log_warn "Skipping (sudo disabled via --no-sudo): $*"
            return 0
            ;;
        unavailable)
            die "Cannot install packages: sudo not available and not running as root. Run as root or install sudo."
            ;;
        root)
            run_or_print "$@"
            ;;
        *)
            run_or_print sudo "$@"
            ;;
    esac
}

install_one_package() {
    local package="$1"
    local manager="$2"
    local sudo_mode="$3"

    case "$manager" in
        brew)
            if brew list "$package" >/dev/null 2>&1; then
                log_info "Already installed (brew): $package"
                return 0
            fi
            run_or_print brew install "$package"
            ;;
        apt)
            if dpkg -s "$package" >/dev/null 2>&1; then
                log_info "Already installed (apt): $package"
                return 0
            fi
            _pkg_run "$sudo_mode" apt-get install -y "$package"
            ;;
        dnf)
            if rpm -q "$package" >/dev/null 2>&1; then
                log_info "Already installed (dnf): $package"
                return 0
            fi
            _pkg_run "$sudo_mode" dnf install -y "$package"
            ;;
        yum)
            if rpm -q "$package" >/dev/null 2>&1; then
                log_info "Already installed (yum): $package"
                return 0
            fi
            _pkg_run "$sudo_mode" yum install -y "$package"
            ;;
        pacman)
            if pacman -Qi "$package" >/dev/null 2>&1; then
                log_info "Already installed (pacman): $package"
                return 0
            fi
            _pkg_run "$sudo_mode" pacman -S --noconfirm "$package"
            ;;
        zypper)
            if rpm -q "$package" >/dev/null 2>&1; then
                log_info "Already installed (zypper): $package"
                return 0
            fi
            _pkg_run "$sudo_mode" zypper install -y "$package"
            ;;
        apk)
            if apk info -e "$package" >/dev/null 2>&1; then
                log_info "Already installed (apk): $package"
                return 0
            fi
            _pkg_run "$sudo_mode" apk add "$package"
            ;;
        *)
            log_warn "No supported package manager. Cannot install: $package"
            ;;
    esac
}

install_packages() {
    local shared_file="$1"
    local profile_file="$2"
    local manager="$3"
    local sudo_mode="$4"
    local apply_mode="$5"

    if [[ -z "$manager" ]]; then
        log_warn "No package manager detected; skipping package phase."
        return 0
    fi

    local packages=()
    local pkg
    while IFS= read -r pkg; do
        packages+=("$pkg")
    done < <(read_package_file "$shared_file")

    while IFS= read -r pkg; do
        packages+=("$pkg")
    done < <(read_package_file "$profile_file")

    if [[ "${#packages[@]}" -eq 0 ]]; then
        log_info "No packages declared for this profile."
        return 0
    fi

    log_info "Installing ${#packages[@]} package(s) via $manager"

    if [[ "$manager" == "apt" && "$apply_mode" -eq 1 ]]; then
        _pkg_run "$sudo_mode" apt-get update
    fi

    for pkg in "${packages[@]}"; do
        install_one_package "$pkg" "$manager" "$sudo_mode"
    done
}

# Install packages gated by feature flags.
# Globs setup/packages/packages.feat-*.txt, extracts the feature name
# from the filename, checks DOTFILES_FEAT_<NAME>, and installs if enabled.
install_feature_packages() {
    local manager="$1"
    local sudo_mode="$2"

    if [[ -z "$manager" ]]; then
        return 0
    fi

    local feat_file
    for feat_file in "$DOTFILES_DIR"/setup/packages/packages.feat-*.txt; do
        [[ -f "$feat_file" ]] || continue
        local basename="${feat_file##*/}"
        local feat_name="${basename#packages.feat-}"
        feat_name="${feat_name%.txt}"
        feat_name="${feat_name^^}"
        local var="DOTFILES_FEAT_${feat_name}"

        if [[ "${!var:-0}" -eq 1 ]]; then
            local pkg
            while IFS= read -r pkg; do
                install_one_package "$pkg" "$manager" "$sudo_mode"
            done < <(read_package_file "$feat_file")
        fi
    done
}
