#!/usr/bin/env bash
# lib/core/connectivity.sh — AWS connectivity checks (SSH, SSM, IMDS)

# Check if IMDS (Instance Metadata Service) is reachable
check_imds() {
    if curl -sf -m 2 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        log_debug "IMDS is reachable"
        return 0
    fi
    log_warn "IMDS is not reachable"
    return 1
}

# Get EC2 instance metadata field
get_instance_metadata() {
    local field="$1"
    curl -sf -m 2 "http://169.254.169.254/latest/meta-data/${field}" 2>/dev/null
}

# Check if SSM Agent is running
check_ssm_agent() {
    if systemctl is-active amazon-ssm-agent &>/dev/null; then
        log_debug "SSM Agent is active"
        return 0
    fi
    log_warn "SSM Agent is not running"
    return 1
}

# Run all connectivity checks and return summary
check_connectivity() {
    local results=()

    if check_imds; then
        results+=("IMDS: OK")
        local instance_id region
        instance_id="$(get_instance_metadata instance-id)"
        region="$(get_instance_metadata placement/region)"
        results+=("Instance: ${instance_id:-unknown}")
        results+=("Region: ${region:-unknown}")
    else
        results+=("IMDS: Unreachable")
    fi

    if check_ssm_agent; then
        results+=("SSM Agent: Active")
    else
        results+=("SSM Agent: Inactive")
    fi

    printf '%s\n' "${results[@]}"
}
