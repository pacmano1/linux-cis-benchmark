#!/usr/bin/env bash
# lib/modules/3-network.sh — CIS Section 3: Network Configuration
# Network kernel modules + sysctl parameters

audit_module_3() {
    local config_file="$1"
    dispatch_audit "$config_file"
}

apply_module_3() {
    local config_file="$1"
    dispatch_apply "$config_file"
}
