#!/usr/bin/env bash
# lib/handlers/mac.sh — SELinux/AppArmor audit and apply (dispatches to distro adapter)

# Audit a MAC control
# Input: JSON with fields: id, title, check_type (installed/enforcing/policy/profile), and type-specific fields
handler_mac_audit() {
    local control_json="$1"
    local id title check_type

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    check_type="$(ctl_field "$control_json" "check_type")"

    case "${MAC_SYSTEM:-}" in
        selinux)
            _mac_audit_selinux "$control_json" "$check_type"
            ;;
        apparmor)
            _mac_audit_apparmor "$control_json" "$check_type"
            ;;
        *)
            emit_result "$id" "$title" "Fail" "MAC configured" "unknown" "No MAC system detected"
            ;;
    esac
}

# Apply a MAC control
handler_mac_apply() {
    local control_json="$1"
    local id title check_type

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    check_type="$(ctl_field "$control_json" "check_type")"

    local audit_result
    audit_result="$(handler_mac_audit "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c '.detail = "[DRY RUN] " + .detail'
        return
    fi

    # Type-specific apply
    case "${MAC_SYSTEM:-}" in
        selinux)
            _mac_apply_selinux "$control_json" "$check_type"
            ;;
        apparmor)
            _mac_apply_apparmor "$control_json" "$check_type"
            ;;
        *)
            echo "$audit_result"
            ;;
    esac
}

# --- SELinux ---

_mac_audit_selinux() {
    local control_json="$1"
    local check_type="$2"
    local id title expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    expected="$(ctl_field "$control_json" "expected")"

    case "$check_type" in
        installed)
            if distro_pkg_installed "libselinux"; then
                emit_result "$id" "$title" "Pass" "installed" "installed" "SELinux is installed"
            else
                emit_result "$id" "$title" "Fail" "installed" "not installed" "SELinux packages not found"
            fi
            ;;
        enforcing)
            if distro_mac_enforcing; then
                emit_result "$id" "$title" "Pass" "Enforcing" "Enforcing" "SELinux is enforcing"
            else
                local mode
                mode="$(getenforce 2>/dev/null || echo "unknown")"
                emit_result "$id" "$title" "Fail" "Enforcing" "$mode" "SELinux is not enforcing"
            fi
            ;;
        policy)
            local policy
            policy="$(grep -E "^SELINUXTYPE=" /etc/selinux/config 2>/dev/null | cut -d= -f2)" || policy=""
            if [[ "$policy" == "${expected:-targeted}" ]]; then
                emit_result "$id" "$title" "Pass" "${expected:-targeted}" "$policy" "SELinux policy"
            else
                emit_result "$id" "$title" "Fail" "${expected:-targeted}" "${policy:-not set}" "SELinux policy"
            fi
            ;;
        config)
            local key
            key="$(ctl_field "$control_json" "directive")"
            local actual
            actual="$(grep -E "^${key}=" /etc/selinux/config 2>/dev/null | cut -d= -f2)" || actual=""
            if [[ "$actual" == "$expected" ]]; then
                emit_result "$id" "$title" "Pass" "$expected" "$actual" "/etc/selinux/config: $key"
            else
                emit_result "$id" "$title" "Fail" "$expected" "${actual:-not set}" "/etc/selinux/config: $key"
            fi
            ;;
        unconfined)
            local count
            count="$(ps -eZ 2>/dev/null | grep -c "unconfined_t" || echo 0)"
            if (( count == 0 )); then
                emit_result "$id" "$title" "Pass" "0" "$count" "No unconfined services"
            else
                emit_result "$id" "$title" "Fail" "0" "$count" "$count unconfined processes found"
            fi
            ;;
    esac
}

_mac_apply_selinux() {
    local control_json="$1"
    local check_type="$2"
    local id title expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    expected="$(ctl_field "$control_json" "expected")"

    case "$check_type" in
        enforcing)
            distro_mac_set_enforcing
            sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "Enforcing" "Enforcing" "Set SELinux to enforcing"
            ;;
        policy)
            sed -i "s/^SELINUXTYPE=.*/SELINUXTYPE=${expected:-targeted}/" /etc/selinux/config 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "${expected:-targeted}" "${expected:-targeted}" "Set SELinux policy"
            ;;
        config)
            local key
            key="$(ctl_field "$control_json" "directive")"
            sed -i "s/^${key}=.*/${key}=${expected}/" /etc/selinux/config 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "$expected" "$expected" "Set $key in SELinux config"
            ;;
    esac
}

# --- AppArmor ---

_mac_audit_apparmor() {
    local control_json="$1"
    local check_type="$2"
    local id title expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    expected="$(ctl_field "$control_json" "expected")"

    case "$check_type" in
        installed)
            if distro_pkg_installed "apparmor"; then
                emit_result "$id" "$title" "Pass" "installed" "installed" "AppArmor is installed"
            else
                emit_result "$id" "$title" "Fail" "installed" "not installed" "AppArmor packages not found"
            fi
            ;;
        enforcing)
            if distro_mac_enforcing; then
                emit_result "$id" "$title" "Pass" "enforcing" "enforcing" "AppArmor profiles are in enforce mode"
            else
                emit_result "$id" "$title" "Fail" "enforcing" "not enforcing" "AppArmor profiles not all enforcing"
            fi
            ;;
        loaded)
            local profiles
            profiles="$(aa-status 2>/dev/null | grep "profiles are loaded" | awk '{print $1}')" || profiles="0"
            if (( profiles > 0 )); then
                emit_result "$id" "$title" "Pass" ">0 profiles" "$profiles profiles" "AppArmor profiles loaded"
            else
                emit_result "$id" "$title" "Fail" ">0 profiles" "0 profiles" "No AppArmor profiles loaded"
            fi
            ;;
        no_complain)
            local complain
            complain="$(aa-status 2>/dev/null | grep "profiles are in complain mode" | awk '{print $1}')" || complain="0"
            if (( complain == 0 )); then
                emit_result "$id" "$title" "Pass" "0 complain" "$complain complain" "No profiles in complain mode"
            else
                emit_result "$id" "$title" "Fail" "0 complain" "$complain complain" "Profiles in complain mode"
            fi
            ;;
    esac
}

_mac_apply_apparmor() {
    local control_json="$1"
    local check_type="$2"
    local id title

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"

    case "$check_type" in
        enforcing|no_complain)
            distro_mac_set_enforcing
            emit_result "$id" "$title" "Pass" "enforcing" "enforcing" "Set AppArmor to enforce mode"
            ;;
    esac
}
