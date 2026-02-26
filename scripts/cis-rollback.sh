#!/usr/bin/env bash
# scripts/cis-rollback.sh — Restore from CIS benchmark backup
# Usage: sudo ./scripts/cis-rollback.sh [OPTIONS]
#
# Options:
#   --force           Skip all interactive prompts
#   --backup DIR      Specify backup directory directly
#   --modules LIST    Comma-separated module numbers (e.g., 1,3,5)
#   --log-level LEVEL Set log level (DEBUG, INFO, WARN, ERROR)
#   --help            Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse CLI arguments
SELECTED_MODULES=()
BACKUP_SPECIFIED=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        --backup)
            BACKUP_SPECIFIED="$2"
            shift 2
            ;;
        --modules)
            IFS=',' read -ra SELECTED_MODULES <<< "$2"
            shift 2
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --help|-h)
            head -15 "${BASH_SOURCE[0]}" | tail -10
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Bootstrap the framework
source "${REPO_ROOT}/lib/core/init.sh"

require_root

# Load configuration
load_master_config

# --- Select backup ---

BACKUP_DIR_PATH=""

if [[ -n "$BACKUP_SPECIFIED" ]]; then
    BACKUP_DIR_PATH="$BACKUP_SPECIFIED"
elif [[ "$FORCE" == true ]]; then
    # Use most recent backup
    BACKUP_DIR_PATH="$(ls -dt "${REPO_ROOT}/${BACKUP_DIR:-backups}"/*/ 2>/dev/null | head -1)"
    if [[ -z "$BACKUP_DIR_PATH" ]]; then
        log_error "No backups found and --force specified"
        exit 1
    fi
else
    # Interactive: show available backups
    printf '\n  Available backups:\n\n' >&2
    list_backups >&2

    printf '\n  Enter backup number: ' >&2
    read -r selection

    local count=0
    for dir in "${REPO_ROOT}/${BACKUP_DIR:-backups}"/*/; do
        if [[ -f "${dir}metadata.json" ]]; then
            count=$((count + 1))
            if [[ "$count" == "$selection" ]]; then
                BACKUP_DIR_PATH="$dir"
                break
            fi
        fi
    done
fi

if [[ -z "$BACKUP_DIR_PATH" || ! -d "$BACKUP_DIR_PATH" ]]; then
    log_error "Invalid backup selection"
    exit 1
fi

# Module scope prompt
prompt_modules

# Confirmation
prompt_confirm_live

# --- Restore ---

log_info "Restoring from: $BACKUP_DIR_PATH"
restore_from_backup "$BACKUP_DIR_PATH"

log_info "Rollback complete."
log_warn "Some changes may require service restarts or a reboot."
