#!/usr/bin/env bash
# lib/core/log.sh — Structured logging (mirrors Write-CISLog from Windows)

# Log levels: DEBUG=0, INFO=1, WARN=2, ERROR=3
declare -A _LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)

_log_level_num() {
    echo "${_LOG_LEVELS[${1:-INFO}]:-1}"
}

# Initialize logging — call after config is loaded
log_init() {
    local log_dir
    log_dir="$(dirname "${LOG_FILE:-reports/cis-benchmark.log}")"
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
}

# Core log function
# Usage: log INFO "message" or log ERROR "message"
log() {
    local level="${1:-INFO}"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    local current_level_num
    current_level_num="$(_log_level_num "${LOG_LEVEL:-INFO}")"
    local msg_level_num
    msg_level_num="$(_log_level_num "$level")"

    # Skip if below configured log level
    if (( msg_level_num < current_level_num )); then
        return 0
    fi

    local color=""
    local reset=""
    if [[ -t 2 ]]; then
        reset=$'\033[0m'
        case "$level" in
            DEBUG) color=$'\033[36m' ;;   # cyan
            INFO)  color=$'\033[32m' ;;   # green
            WARN)  color=$'\033[33m' ;;   # yellow
            ERROR) color=$'\033[31m' ;;   # red
        esac
    fi

    # Write to stderr (always)
    printf '%s[%s] [%-5s] %s%s\n' "$color" "$timestamp" "$level" "$message" "$reset" >&2

    # Append to log file if configured
    if [[ -n "${LOG_FILE:-}" ]]; then
        printf '[%s] [%-5s] %s\n' "$timestamp" "$level" "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_debug() { log DEBUG "$@"; }
log_info()  { log INFO "$@"; }
log_warn()  { log WARN "$@"; }
log_error() { log ERROR "$@"; }
