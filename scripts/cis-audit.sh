#!/usr/bin/env bash
# scripts/cis-audit.sh — CIS Linux Benchmark L1 read-only audit
# Usage: sudo ./scripts/cis-audit.sh [OPTIONS]
#
# Options:
#   --force           Skip all interactive prompts
#   --skip-gdm        Skip GDM desktop controls
#   --modules LIST    Comma-separated module numbers (e.g., 1,3,5)
#   --log-level LEVEL Set log level (DEBUG, INFO, WARN, ERROR)
#   --help            Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse CLI arguments before sourcing init (to set FORCE early)
SELECTED_MODULES=()
SKIP_GDM=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        --skip-gdm)
            SKIP_GDM=true
            shift
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

# Load configuration
load_all_config

# --- Interactive prompts ---

# GDM prompt (skip desktop controls on headless servers)
if [[ "$SKIP_GDM" == false ]]; then
    prompt_yn "Is this a GDM desktop system?" "n"
    if [[ "$REPLY" == "n" ]]; then
        SKIP_GDM=true
    fi
fi

if [[ "$SKIP_GDM" == true ]]; then
    # Add GDM control IDs to skip list
    add_skip_ids "1.8.1" "1.8.2" "1.8.3" "1.8.4" "1.8.5" "1.8.6" "1.8.7" "1.8.8" "1.8.9" "1.8.10"
    log_info "GDM controls excluded"
fi

# Module selection prompt
prompt_modules

# --- Run audit ---

log_info "Starting CIS L1 audit..."
log_info "Modules: ${SELECTED_MODULES[*]}"

# Create results file
RESULTS_FILE="${REPO_ROOT}/${REPORT_DIR:-reports}/results_$(date '+%Y%m%d_%H%M%S').ndjson"
mkdir -p "$(dirname "$RESULTS_FILE")"
: > "$RESULTS_FILE"

# Run each selected module
for mod_num in "${SELECTED_MODULES[@]}"; do
    local_config="$(module_config_file "$mod_num")"
    local_name="$(module_name "$mod_num")"

    log_info "Auditing section ${mod_num}: ${local_name}..."

    # Check if module audit function exists
    local_func="audit_module_${mod_num}"
    if declare -f "$local_func" &>/dev/null; then
        "$local_func" "$local_config" >> "$RESULTS_FILE"
    else
        log_warn "No audit function for module ${mod_num} (${local_func})"
    fi
done

# --- Generate reports ---

log_info "Generating reports..."

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
JSON_REPORT="${REPO_ROOT}/${REPORT_DIR:-reports}/cis-audit_${TIMESTAMP}.json"
HTML_REPORT="${REPO_ROOT}/${REPORT_DIR:-reports}/cis-audit_${TIMESTAMP}.html"

generate_json_report "$RESULTS_FILE" "$JSON_REPORT"
generate_html_report "$RESULTS_FILE" "$HTML_REPORT"

# Print console summary
print_summary "$RESULTS_FILE"

log_info "Audit complete. Reports:"
log_info "  JSON: $JSON_REPORT"
log_info "  HTML: $HTML_REPORT"
