#!/usr/bin/env bash
# lib/modules/6-logging.sh — CIS Section 6: Logging and Auditing

audit_module_6() {
    local config_file="$1"
    dispatch_audit "$config_file"
}

apply_module_6() {
    local config_file="$1"
    dispatch_apply "$config_file"
}
