#!/usr/bin/env bash
# lib/distro/ubuntu2404.sh — Ubuntu 24.04 adapter (apt, apparmor_status, ufw, pam-auth-update)
# Provides standard distro_* functions for Ubuntu 24.04 LTS

DISTRO_ID="ubuntu2404"
DISTRO_LABEL="Ubuntu 24.04 LTS"

# Package management
distro_pkg_installed() {
    local pkg="$1"
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
}

distro_pkg_install() {
    local pkg="$1"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" &>/dev/null
}

distro_pkg_remove() {
    local pkg="$1"
    DEBIAN_FRONTEND=noninteractive apt-get purge -y "$pkg" &>/dev/null
}

# Mandatory Access Control (AppArmor)
distro_mac_status() {
    if command_exists apparmor_status; then
        apparmor_status 2>/dev/null
    elif command_exists aa-status; then
        aa-status 2>/dev/null
    else
        echo "AppArmor tools not installed"
        return 1
    fi
}

distro_mac_enforcing() {
    local profiles loaded enforced
    if command_exists aa-status; then
        profiles=$(aa-status 2>/dev/null | grep "profiles are loaded" | awk '{print $1}')
        enforced=$(aa-status 2>/dev/null | grep "profiles are in enforce mode" | awk '{print $1}')
        [[ -n "$profiles" && "$profiles" -gt 0 && "$enforced" -gt 0 ]]
    else
        return 1
    fi
}

distro_mac_set_enforcing() {
    aa-enforce /etc/apparmor.d/* 2>/dev/null
}

# Firewall (ufw)
distro_firewall_active() {
    ufw status 2>/dev/null | grep -q "Status: active"
}

distro_firewall_default_zone() {
    # ufw doesn't use zones — return default policy
    ufw status verbose 2>/dev/null | grep "Default:" | head -1
}

distro_firewall_list_rules() {
    ufw status numbered 2>/dev/null
}

# PAM / Authentication
distro_pam_check_profile() {
    pam-auth-update --package 2>/dev/null
}

distro_pam_faillock_enabled() {
    grep -r "pam_faillock" /etc/pam.d/ &>/dev/null
}

# Time sync
distro_time_sync_service() {
    if systemctl is-active chrony &>/dev/null; then
        echo "chrony"
    elif systemctl is-active systemd-timesyncd &>/dev/null; then
        echo "systemd-timesyncd"
    else
        echo "chrony"  # preferred default
    fi
}

distro_time_sync_active() {
    systemctl is-active chrony &>/dev/null || systemctl is-active systemd-timesyncd &>/dev/null
}
