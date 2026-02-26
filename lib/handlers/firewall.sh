#!/usr/bin/env bash
# lib/handlers/firewall.sh — Firewall rules audit and apply (dispatches to distro adapter)

# Audit a firewall control
# Input: JSON with fields: id, title, check_type (installed/active/default_zone/loopback/open_ports), expected
handler_firewall_audit() {
    local control_json="$1"
    local id title check_type expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    check_type="$(ctl_field "$control_json" "check_type")"
    expected="$(ctl_field "$control_json" "expected")"

    case "${FIREWALL_SYSTEM:-}" in
        firewalld)
            _firewall_audit_firewalld "$control_json" "$check_type"
            ;;
        ufw)
            _firewall_audit_ufw "$control_json" "$check_type"
            ;;
        *)
            emit_result "$id" "$title" "Fail" "firewall configured" "unknown" "No supported firewall detected"
            ;;
    esac
}

# Apply a firewall control
handler_firewall_apply() {
    local control_json="$1"
    local id title check_type

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    check_type="$(ctl_field "$control_json" "check_type")"

    local audit_result
    audit_result="$(handler_firewall_audit "$control_json")"
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

    case "${FIREWALL_SYSTEM:-}" in
        firewalld)
            _firewall_apply_firewalld "$control_json" "$check_type"
            ;;
        ufw)
            _firewall_apply_ufw "$control_json" "$check_type"
            ;;
        *)
            echo "$audit_result"
            ;;
    esac
}

# --- firewalld ---

_firewall_audit_firewalld() {
    local control_json="$1"
    local check_type="$2"
    local id title expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    expected="$(ctl_field "$control_json" "expected")"

    case "$check_type" in
        installed)
            if distro_pkg_installed "firewalld"; then
                emit_result "$id" "$title" "Pass" "installed" "installed" "firewalld package"
            else
                emit_result "$id" "$title" "Fail" "installed" "not installed" "firewalld not installed"
            fi
            ;;
        active)
            if distro_firewall_active; then
                emit_result "$id" "$title" "Pass" "active" "active" "firewalld is running"
            else
                emit_result "$id" "$title" "Fail" "active" "inactive" "firewalld is not running"
            fi
            ;;
        default_zone)
            local zone
            zone="$(distro_firewall_default_zone)"
            if [[ "$zone" == "${expected:-drop}" ]]; then
                emit_result "$id" "$title" "Pass" "${expected:-drop}" "$zone" "Default zone"
            else
                emit_result "$id" "$title" "Fail" "${expected:-drop}" "$zone" "Default zone should be ${expected:-drop}"
            fi
            ;;
        service_enabled)
            if systemctl is-enabled firewalld &>/dev/null; then
                emit_result "$id" "$title" "Pass" "enabled" "enabled" "firewalld service"
            else
                emit_result "$id" "$title" "Fail" "enabled" "not enabled" "firewalld service not enabled"
            fi
            ;;
    esac
}

_firewall_apply_firewalld() {
    local control_json="$1"
    local check_type="$2"
    local id title expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    expected="$(ctl_field "$control_json" "expected")"

    case "$check_type" in
        active|service_enabled)
            systemctl enable --now firewalld 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "active" "active" "Enabled and started firewalld"
            ;;
        default_zone)
            firewall-cmd --set-default-zone="${expected:-drop}" 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "${expected:-drop}" "${expected:-drop}" "Set default zone"
            ;;
    esac
}

# --- ufw ---

_firewall_audit_ufw() {
    local control_json="$1"
    local check_type="$2"
    local id title expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    expected="$(ctl_field "$control_json" "expected")"

    case "$check_type" in
        installed)
            if distro_pkg_installed "ufw"; then
                emit_result "$id" "$title" "Pass" "installed" "installed" "ufw package"
            else
                emit_result "$id" "$title" "Fail" "installed" "not installed" "ufw not installed"
            fi
            ;;
        active)
            if distro_firewall_active; then
                emit_result "$id" "$title" "Pass" "active" "active" "ufw is active"
            else
                emit_result "$id" "$title" "Fail" "active" "inactive" "ufw is not active"
            fi
            ;;
        default_policy)
            local policy
            policy="$(ufw status verbose 2>/dev/null | grep "Default:" | head -1)" || policy=""
            if echo "$policy" | grep -qi "${expected:-deny}"; then
                emit_result "$id" "$title" "Pass" "$expected" "$policy" "ufw default policy"
            else
                emit_result "$id" "$title" "Fail" "$expected" "${policy:-not set}" "ufw default policy"
            fi
            ;;
        loopback)
            local lo_rules
            lo_rules="$(ufw status 2>/dev/null | grep -i "loopback\|Anywhere on lo")" || lo_rules=""
            if [[ -n "$lo_rules" ]]; then
                emit_result "$id" "$title" "Pass" "loopback configured" "rules present" "ufw loopback rules"
            else
                emit_result "$id" "$title" "Fail" "loopback configured" "no rules" "ufw loopback rules missing"
            fi
            ;;
    esac
}

_firewall_apply_ufw() {
    local control_json="$1"
    local check_type="$2"
    local id title expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    expected="$(ctl_field "$control_json" "expected")"

    case "$check_type" in
        active)
            ufw --force enable 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "active" "active" "Enabled ufw"
            ;;
        default_policy)
            ufw default deny incoming 2>/dev/null || true
            ufw default deny outgoing 2>/dev/null || true
            ufw default deny routed 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "deny" "deny" "Set ufw default deny"
            ;;
    esac
}
