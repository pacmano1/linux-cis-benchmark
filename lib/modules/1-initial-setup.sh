#!/usr/bin/env bash
# lib/modules/1-initial-setup.sh — CIS Section 1: Initial Setup
# Filesystem, packages, MAC, bootloader, sysctl, banners, GDM

audit_module_1() {
    local config_file="$1"
    dispatch_audit "$config_file"
}

apply_module_1() {
    local config_file="$1"
    dispatch_apply "$config_file"
}
