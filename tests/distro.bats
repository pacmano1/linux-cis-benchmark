#!/usr/bin/env bats
# tests/distro.bats — Test distro detection and adapter loading

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$REPO_ROOT/lib/core/log.sh"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/core/config.sh"
    LOG_LEVEL="ERROR"
}

@test "detect.sh is sourceable" {
    source "$REPO_ROOT/lib/distro/detect.sh"
}

@test "rhel9 adapter defines all required functions" {
    source "$REPO_ROOT/lib/distro/rhel9.sh"

    declare -f distro_pkg_installed > /dev/null || fail "Missing distro_pkg_installed"
    declare -f distro_pkg_install > /dev/null || fail "Missing distro_pkg_install"
    declare -f distro_pkg_remove > /dev/null || fail "Missing distro_pkg_remove"
    declare -f distro_mac_status > /dev/null || fail "Missing distro_mac_status"
    declare -f distro_mac_enforcing > /dev/null || fail "Missing distro_mac_enforcing"
    declare -f distro_firewall_active > /dev/null || fail "Missing distro_firewall_active"
    declare -f distro_time_sync_service > /dev/null || fail "Missing distro_time_sync_service"
    declare -f distro_time_sync_active > /dev/null || fail "Missing distro_time_sync_active"
}

@test "ubuntu2404 adapter defines all required functions" {
    source "$REPO_ROOT/lib/distro/ubuntu2404.sh"

    declare -f distro_pkg_installed > /dev/null || fail "Missing distro_pkg_installed"
    declare -f distro_pkg_install > /dev/null || fail "Missing distro_pkg_install"
    declare -f distro_pkg_remove > /dev/null || fail "Missing distro_pkg_remove"
    declare -f distro_mac_status > /dev/null || fail "Missing distro_mac_status"
    declare -f distro_mac_enforcing > /dev/null || fail "Missing distro_mac_enforcing"
    declare -f distro_firewall_active > /dev/null || fail "Missing distro_firewall_active"
    declare -f distro_time_sync_service > /dev/null || fail "Missing distro_time_sync_service"
    declare -f distro_time_sync_active > /dev/null || fail "Missing distro_time_sync_active"
}

@test "rhel9 adapter sets correct DISTRO_ID" {
    source "$REPO_ROOT/lib/distro/rhel9.sh"
    [ "$DISTRO_ID" = "rhel9" ]
}

@test "ubuntu2404 adapter sets correct DISTRO_ID" {
    source "$REPO_ROOT/lib/distro/ubuntu2404.sh"
    [ "$DISTRO_ID" = "ubuntu2404" ]
}

@test "rhel9 adapter reports chronyd as time sync" {
    source "$REPO_ROOT/lib/distro/rhel9.sh"
    local svc
    svc=$(distro_time_sync_service)
    [ "$svc" = "chronyd" ]
}

@test "rhel9 config sets correct MAC and firewall" {
    source "$REPO_ROOT/config/distro/rhel9.conf"
    [ "$MAC_SYSTEM" = "selinux" ]
    [ "$FIREWALL_SYSTEM" = "firewalld" ]
    [ "$PAM_TOOL" = "authselect" ]
}

@test "ubuntu2404 config sets correct MAC and firewall" {
    source "$REPO_ROOT/config/distro/ubuntu2404.conf"
    [ "$MAC_SYSTEM" = "apparmor" ]
    [ "$FIREWALL_SYSTEM" = "ufw" ]
    [ "$PAM_TOOL" = "pam-auth-update" ]
}

@test "distro adapters have matching function signatures" {
    # Both adapters must define the same set of functions
    source "$REPO_ROOT/lib/distro/rhel9.sh"
    local rhel_funcs
    rhel_funcs=$(declare -F | grep 'distro_' | awk '{print $3}' | sort)

    source "$REPO_ROOT/lib/distro/ubuntu2404.sh"
    local ubuntu_funcs
    ubuntu_funcs=$(declare -F | grep 'distro_' | awk '{print $3}' | sort)

    [ "$rhel_funcs" = "$ubuntu_funcs" ] || fail "Adapter function mismatch:\nRHEL: $rhel_funcs\nUbuntu: $ubuntu_funcs"
}
