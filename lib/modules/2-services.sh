#!/usr/bin/env bash
# lib/modules/2-services.sh — CIS Section 2: Services
# Server/client services, time synchronization, cron

audit_module_2() {
    local config_file="$1"
    dispatch_audit "$config_file"
}

apply_module_2() {
    local config_file="$1"
    dispatch_apply "$config_file"
}
