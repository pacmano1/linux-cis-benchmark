#!/usr/bin/env bash
# lib/modules/4-firewall.sh — CIS Section 4: Firewall Configuration

audit_module_4() {
    local config_file="$1"
    dispatch_audit "$config_file"
}

apply_module_4() {
    local config_file="$1"
    dispatch_apply "$config_file"
}
