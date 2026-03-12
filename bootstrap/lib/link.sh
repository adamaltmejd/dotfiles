#!/usr/bin/env bash

is_same_content() {
    local target="$1"
    local expected="$2"

    [[ -f "$target" ]] || return 1
    [[ "$(cat "$target")" == "$expected" ]]
}

backup_target() {
    local target="$1"
    local backup_dir="$2"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
        return 0
    fi

    local rel="${target#/}"
    local backup_path="$backup_dir/$rel"

    if [[ -e "$backup_path" || -L "$backup_path" ]]; then
        backup_path="$backup_path.$(timestamp)"
    fi

    run_or_print mkdir -p "$(dirname "$backup_path")"
    run_or_print mv "$target" "$backup_path"
    log_info "Backed up $target -> $backup_path"
}

write_file_from_string() {
    local target="$1"
    local content="$2"
    local backup_dir="$3"

    if is_same_content "$target" "$content"; then
        log_info "Unchanged $target"
        return 0
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        backup_target "$target" "$backup_dir"
    fi

    run_or_print mkdir -p "$(dirname "$target")"

    if [[ "$APPLY" -eq 1 ]]; then
        printf '%s\n' "$content" > "$target"
    else
        printf '[dry-run] write %s\n' "$target"
    fi
}

link_file() {
    local source="$1"
    local target="$2"
    local backup_dir="$3"

    if [[ ! -e "$source" ]]; then
        log_warn "Source does not exist, skipping: $source"
        return 0
    fi

    if [[ -L "$target" ]]; then
        local current_target
        current_target="$(readlink "$target")"
        if [[ "$current_target" == "$source" ]]; then
            log_info "Already linked $target -> $source"
            return 0
        fi
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        backup_target "$target" "$backup_dir"
    fi

    run_or_print mkdir -p "$(dirname "$target")"
    run_or_print ln -s "$source" "$target"
}
