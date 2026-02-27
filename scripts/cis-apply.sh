#!/usr/bin/env bash
# scripts/cis-apply.sh — CIS Linux Benchmark L1 apply changes
# Usage: sudo ./scripts/cis-apply.sh [OPTIONS]
#
# Options:
#   --force              Skip all interactive prompts
#   --dry-run BOOL       Set dry-run mode (true/false, default: true)
#   --skip-gdm           Skip GDM desktop controls
#   --modules LIST       Comma-separated module numbers (e.g., 1,3,5)
#   --harden-firewall    Enable firewall rule hardening
#   --apply-all          Override audit-only controls (services, firewall, etc.)
#   --log-level LEVEL    Set log level (DEBUG, INFO, WARN, ERROR)
#   --help               Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse CLI arguments
SELECTED_MODULES=()
SKIP_GDM=false
HARDEN_FIREWALL=false
APPLY_ALL=false
DRY_RUN_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN="$2"
            DRY_RUN_SET=true
            shift 2
            ;;
        --skip-gdm)
            SKIP_GDM=true
            shift
            ;;
        --modules)
            IFS=',' read -ra SELECTED_MODULES <<< "$2"
            shift 2
            ;;
        --harden-firewall)
            HARDEN_FIREWALL=true
            shift
            ;;
        --apply-all)
            APPLY_ALL=true
            shift
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --help|-h)
            head -17 "${BASH_SOURCE[0]}" | tail -12
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
load_all_config

# --- Interactive prompts ---

# Mode prompt
if [[ "$DRY_RUN_SET" == false ]]; then
    prompt_mode
    if [[ "$REPLY" == "l" ]]; then
        DRY_RUN=false
    else
        DRY_RUN=true
    fi
fi
export DRY_RUN

# GDM prompt
if [[ "$SKIP_GDM" == false ]]; then
    prompt_yn "Is this a GDM desktop system?" "n"
    if [[ "$REPLY" == "n" ]]; then
        SKIP_GDM=true
    fi
fi

if [[ "$SKIP_GDM" == true ]]; then
    add_skip_ids "1.8.1" "1.8.2" "1.8.3" "1.8.4" "1.8.5" "1.8.6" "1.8.7" "1.8.8" "1.8.9" "1.8.10"
    log_info "GDM controls excluded"
fi

# Module selection
prompt_modules

# Firewall hardening prompt
if [[ "$HARDEN_FIREWALL" == false ]]; then
    prompt_yn "Enable firewall rule hardening?" "n"
    if [[ "$REPLY" == "y" ]]; then
        HARDEN_FIREWALL=true
    fi
fi
export HARDEN_FIREWALL
export APPLY_ALL

# Live mode confirmation
if [[ "$DRY_RUN" == false ]]; then
    prompt_confirm_live
fi

# --- Apply ---

if [[ "$DRY_RUN" == true ]]; then
    log_info "Starting CIS L1 apply (DRY RUN)..."
else
    log_info "Starting CIS L1 apply (LIVE MODE)..."
    BACKUP_PATH="$(create_backup)"
    log_info "Backup created: $BACKUP_PATH"
fi

log_info "Modules: ${SELECTED_MODULES[*]}"

# Create results file
RESULTS_FILE="${REPO_ROOT}/${REPORT_DIR:-reports}/apply_$(date '+%Y%m%d_%H%M%S').ndjson"
mkdir -p "$(dirname "$RESULTS_FILE")"
: > "$RESULTS_FILE"

# Run each selected module
for mod_num in "${SELECTED_MODULES[@]}"; do
    local_config="$(module_config_file "$mod_num")"
    local_name="$(module_name "$mod_num")"

    log_info "Applying section ${mod_num}: ${local_name}..."

    local_func="apply_module_${mod_num}"
    if declare -f "$local_func" &>/dev/null; then
        "$local_func" "$local_config" >> "$RESULTS_FILE"
    else
        log_warn "No apply function for module ${mod_num} (${local_func})"
    fi
done

# --- Post-apply audit (live mode only) ---

if [[ "$DRY_RUN" == false ]]; then
    log_info "Running post-apply audit..."
    POST_RESULTS="${REPO_ROOT}/${REPORT_DIR:-reports}/post-apply_$(date '+%Y%m%d_%H%M%S').ndjson"
    : > "$POST_RESULTS"

    for mod_num in "${SELECTED_MODULES[@]}"; do
        local_config="$(module_config_file "$mod_num")"
        local_func="audit_module_${mod_num}"
        if declare -f "$local_func" &>/dev/null; then
            "$local_func" "$local_config" >> "$POST_RESULTS"
        fi
    done

    print_summary "$POST_RESULTS"
else
    printf '\n  %sDry Run Complete — no changes were made.%s\n\n' "$COLOR_CYAN" "$COLOR_RESET"
fi

log_info "Apply complete."
