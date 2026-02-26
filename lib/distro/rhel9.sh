#!/usr/bin/env bash
# lib/distro/rhel9.sh — RHEL 9 adapter (dnf, sestatus, firewall-cmd, authselect)
# Provides standard distro_* functions for RHEL-family 9.x

DISTRO_ID="rhel9"
DISTRO_LABEL="RHEL 9"

# Package management
distro_pkg_installed() {
    local pkg="$1"
    rpm -q "$pkg" &>/dev/null
}

distro_pkg_install() {
    local pkg="$1"
    dnf install -y "$pkg" &>/dev/null
}

distro_pkg_remove() {
    local pkg="$1"
    dnf remove -y "$pkg" &>/dev/null
}

# Mandatory Access Control (SELinux)
distro_mac_status() {
    if command_exists sestatus; then
        sestatus 2>/dev/null
    elif command_exists getenforce; then
        getenforce 2>/dev/null
    else
        echo "SELinux tools not installed"
        return 1
    fi
}

distro_mac_enforcing() {
    local mode
    mode="$(getenforce 2>/dev/null)"
    [[ "$mode" == "Enforcing" ]]
}

distro_mac_set_enforcing() {
    setenforce 1 2>/dev/null
}

# Firewall
distro_firewall_active() {
    systemctl is-active firewalld &>/dev/null
}

distro_firewall_default_zone() {
    firewall-cmd --get-default-zone 2>/dev/null
}

distro_firewall_list_rules() {
    firewall-cmd --list-all 2>/dev/null
}

# PAM / Authentication
distro_pam_check_profile() {
    authselect current 2>/dev/null
}

distro_pam_faillock_enabled() {
    authselect current 2>/dev/null | grep -q "with-faillock"
}

# Crypto policy (RHEL-specific)
distro_crypto_policy() {
    update-crypto-policies --show 2>/dev/null
}

distro_crypto_policy_set() {
    local policy="$1"
    update-crypto-policies --set "$policy" 2>/dev/null
}

# Time sync
distro_time_sync_service() {
    echo "chronyd"
}

distro_time_sync_active() {
    systemctl is-active chronyd &>/dev/null
}
