#!/usr/bin/env bash
# lib/modules/7-maintenance.sh — CIS Section 7: System Maintenance

audit_module_7() {
    local config_file="$1"
    dispatch_audit "$config_file"
}

apply_module_7() {
    local config_file="$1"
    dispatch_apply "$config_file"
}
