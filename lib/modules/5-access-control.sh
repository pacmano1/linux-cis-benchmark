#!/usr/bin/env bash
# lib/modules/5-access-control.sh — CIS Section 5: Access, Authentication and Authorization

audit_module_5() {
    local config_file="$1"
    dispatch_audit "$config_file"
}

apply_module_5() {
    local config_file="$1"
    dispatch_apply "$config_file"
}
