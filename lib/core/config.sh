#!/usr/bin/env bash
# lib/core/config.sh — Load configuration + exclusions (mirrors Get-CISConfiguration)

# Global state set by config loading
_SKIP_IDS=""
_SKIP_REASONS=""
_MODIFY_JSON=""

# Load master configuration
load_master_config() {
    local config_file="${REPO_ROOT}/config/master.conf"
    if [[ ! -f "$config_file" ]]; then
        log_error "Master config not found: $config_file"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$config_file"
    log_debug "Loaded master config: $config_file"
}

# Load distro-specific configuration (overrides master settings)
load_distro_config() {
    local distro_id="${DISTRO_ID:-}"
    if [[ -z "$distro_id" ]]; then
        log_warn "No distro detected, skipping distro config"
        return 0
    fi
    local config_file="${REPO_ROOT}/config/distro/${distro_id}.conf"
    if [[ ! -f "$config_file" ]]; then
        log_warn "No distro config found for $distro_id: $config_file"
        return 0
    fi
    # shellcheck source=/dev/null
    source "$config_file"
    log_debug "Loaded distro config: $config_file"
}

# Load AWS exclusions
load_aws_exclusions() {
    local exclusions_file="${REPO_ROOT}/${AWS_EXCLUSIONS_FILE:-config/aws-exclusions.json}"

    if [[ ! -f "$exclusions_file" ]]; then
        log_debug "No AWS exclusions file: $exclusions_file"
        return 0
    fi

    # Load skip IDs (one per line for grep matching)
    _SKIP_IDS=$(jq -r '.skip[]?.id // empty' "$exclusions_file" 2>/dev/null)

    # Load skip reasons as JSON object { "id": "reason", ... }
    _SKIP_REASONS=$(jq -c '
        [.skip[]? | {key: .id, value: .reason}] | from_entries
    ' "$exclusions_file" 2>/dev/null)

    # Load modify rules as JSON object
    _MODIFY_JSON=$(jq -c '.modify // {}' "$exclusions_file" 2>/dev/null)

    local skip_count
    skip_count=$(echo "$_SKIP_IDS" | grep -c . 2>/dev/null || echo 0)
    local modify_count
    modify_count=$(echo "$_MODIFY_JSON" | jq 'length' 2>/dev/null || echo 0)
    log_info "Loaded AWS exclusions: ${skip_count} skipped, ${modify_count} modified"
}

# Add runtime skip IDs (e.g., from --skip-gdm flag)
add_skip_ids() {
    local ids=("$@")
    for id in "${ids[@]}"; do
        _SKIP_IDS+=$'\n'"$id"
        _SKIP_REASONS=$(echo "$_SKIP_REASONS" | jq -c --arg id "$id" --arg reason "Excluded by runtime flag" '. + {($id): $reason}')
    done
}

# Detect if running on AWS EC2
is_aws_ec2() {
    if [[ "${AWS_MODE:-auto}" == "true" ]]; then
        return 0
    elif [[ "${AWS_MODE:-auto}" == "false" ]]; then
        return 1
    fi
    # Auto-detect via IMDS
    if curl -sf -m 2 http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
        return 0
    fi
    # Fallback: check DMI
    if [[ -f /sys/class/dmi/id/product_uuid ]]; then
        if grep -qi '^ec2' /sys/class/dmi/id/product_uuid 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Master config load sequence
load_all_config() {
    load_master_config
    load_distro_config

    # Load AWS exclusions if on EC2
    if is_aws_ec2; then
        log_info "AWS EC2 detected — loading exclusions"
        load_aws_exclusions
    else
        log_info "Not running on AWS EC2 — no AWS exclusions applied"
    fi
}

# Get list of enabled module numbers
get_enabled_modules() {
    local modules=()
    [[ "${MODULE_1_INITIAL_SETUP:-1}" == "1" ]] && modules+=(1)
    [[ "${MODULE_2_SERVICES:-1}" == "1" ]] && modules+=(2)
    [[ "${MODULE_3_NETWORK:-1}" == "1" ]] && modules+=(3)
    [[ "${MODULE_4_FIREWALL:-1}" == "1" ]] && modules+=(4)
    [[ "${MODULE_5_ACCESS_CONTROL:-1}" == "1" ]] && modules+=(5)
    [[ "${MODULE_6_LOGGING:-1}" == "1" ]] && modules+=(6)
    [[ "${MODULE_7_MAINTENANCE:-1}" == "1" ]] && modules+=(7)
    echo "${modules[@]}"
}

# Map module number to config file path
module_config_file() {
    local num="$1"
    case "$num" in
        1) echo "${REPO_ROOT}/config/modules/1-initial-setup.json" ;;
        2) echo "${REPO_ROOT}/config/modules/2-services.json" ;;
        3) echo "${REPO_ROOT}/config/modules/3-network.json" ;;
        4) echo "${REPO_ROOT}/config/modules/4-firewall.json" ;;
        5) echo "${REPO_ROOT}/config/modules/5-access-control.json" ;;
        6) echo "${REPO_ROOT}/config/modules/6-logging.json" ;;
        7) echo "${REPO_ROOT}/config/modules/7-maintenance.json" ;;
        *) log_error "Unknown module number: $num"; return 1 ;;
    esac
}

# Map module number to human-readable name
module_name() {
    local num="$1"
    case "$num" in
        1) echo "Initial Setup" ;;
        2) echo "Services" ;;
        3) echo "Network Configuration" ;;
        4) echo "Firewall Configuration" ;;
        5) echo "Access, Authentication and Authorization" ;;
        6) echo "Logging and Auditing" ;;
        7) echo "System Maintenance" ;;
        *) echo "Unknown ($num)" ;;
    esac
}
