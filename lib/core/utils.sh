#!/usr/bin/env bash
# lib/core/utils.sh — Shared utilities: emit_result(), color, assertions

# Emit a single NDJSON audit result line
# Usage: emit_result "1.1.1" "Title" "Pass|Fail|Skip" "expected" "actual" "detail"
emit_result() {
    local id="$1"
    local title="$2"
    local status="$3"
    local expected="${4:-}"
    local actual="${5:-}"
    local detail="${6:-}"

    # Escape strings for JSON safety
    local json
    json=$(jq -cn \
        --arg id "$id" \
        --arg title "$title" \
        --arg status "$status" \
        --arg expected "$expected" \
        --arg actual "$actual" \
        --arg detail "$detail" \
        '{id: $id, title: $title, status: $status, expected: $expected, actual: $actual, detail: $detail}')
    echo "$json"
}

# Emit a skipped control result
emit_skipped() {
    local id="$1"
    local title="$2"
    local reason="${3:-Excluded by configuration}"
    emit_result "$id" "$title" "Skip" "" "" "$reason"
}

# Check if running as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (or with sudo)"
        exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Require a command or exit
require_command() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command_exists "$cmd"; then
        log_error "Required command '$cmd' not found. Install package: $pkg"
        exit 1
    fi
}

# Color helpers (only when stdout is a terminal)
if [[ -t 1 ]]; then
    COLOR_RED=$'\033[31m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_BLUE=$'\033[34m'
    COLOR_CYAN=$'\033[36m'
    COLOR_BOLD=$'\033[1m'
    COLOR_RESET=$'\033[0m'
else
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_CYAN=""
    COLOR_BOLD=""
    COLOR_RESET=""
fi

# Print a summary line with color
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        Pass)  printf '%s[PASS]%s  %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$message" ;;
        Fail)  printf '%s[FAIL]%s  %s\n' "$COLOR_RED" "$COLOR_RESET" "$message" ;;
        Skip)  printf '%s[SKIP]%s  %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$message" ;;
        *)     printf '[%s]  %s\n' "$status" "$message" ;;
    esac
}

# Read a JSON array of controls from a module config file
# Returns NDJSON (one control per line)
read_controls() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi
    jq -c '.controls[]' "$config_file"
}

# Get a field from a JSON control line
ctl_field() {
    local json="$1"
    local field="$2"
    echo "$json" | jq -r ".$field // empty"
}

# Check if a control should be skipped (by the loaded exclusion list)
is_control_skipped() {
    local control_id="$1"
    if [[ -n "${_SKIP_IDS:-}" ]]; then
        echo "$_SKIP_IDS" | grep -qxF "$control_id"
        return $?
    fi
    return 1
}

# Get modification for a control (returns JSON or empty)
get_control_modification() {
    local control_id="$1"
    if [[ -n "${_MODIFY_JSON:-}" ]]; then
        echo "$_MODIFY_JSON" | jq -c --arg id "$control_id" '.[$id] // empty'
    fi
}

# Apply modification overrides to a control JSON
apply_modifications() {
    local control_json="$1"
    local control_id
    control_id="$(ctl_field "$control_json" "id")"

    local mod
    mod="$(get_control_modification "$control_id")"
    if [[ -z "$mod" ]]; then
        echo "$control_json"
        return
    fi

    local field value
    field="$(echo "$mod" | jq -r '.field // empty')"
    value="$(echo "$mod" | jq -r '.value // empty')"
    if [[ -n "$field" && -n "$value" ]]; then
        echo "$control_json" | jq -c --arg f "$field" --arg v "$value" '.[$f] = $v'
    else
        echo "$control_json"
    fi
}

# Resolve a control: check skip, apply mods, check distro
resolve_control() {
    local control_json="$1"
    local control_id
    control_id="$(ctl_field "$control_json" "id")"
    local control_title
    control_title="$(ctl_field "$control_json" "title")"

    # Check skip list
    if is_control_skipped "$control_id"; then
        local reason=""
        if [[ -n "${_SKIP_REASONS:-}" ]]; then
            reason=$(echo "$_SKIP_REASONS" | jq -r --arg id "$control_id" '.[$id] // "Excluded by configuration"')
        fi
        emit_skipped "$control_id" "$control_title" "$reason"
        return 1  # Signal: skipped
    fi

    # Check distro_only field
    local distro_only
    distro_only="$(ctl_field "$control_json" "distro_only")"
    if [[ -n "$distro_only" && "$distro_only" != "${DISTRO_ID:-}" ]]; then
        emit_skipped "$control_id" "$control_title" "Not applicable to ${DISTRO_LABEL:-this distro} (${distro_only} only)"
        return 1
    fi

    # Apply modifications and return resolved JSON
    apply_modifications "$control_json"
    return 0
}
