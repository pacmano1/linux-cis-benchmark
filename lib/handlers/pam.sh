#!/usr/bin/env bash
# lib/handlers/pam.sh — Audit and apply PAM configuration (dispatches to distro adapter)

# Audit a PAM control
# Input: JSON with fields: id, title, check_type (faillock/pwquality/config), and type-specific fields
handler_pam_audit() {
    local control_json="$1"
    local id title check_type

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    check_type="$(ctl_field "$control_json" "check_type")"

    case "$check_type" in
        faillock)
            _pam_audit_faillock "$control_json"
            ;;
        pwquality)
            _pam_audit_pwquality "$control_json"
            ;;
        config)
            # Generic PAM file content check — delegate to file-content handler
            handler_file_content_audit "$control_json"
            ;;
        *)
            emit_result "$id" "$title" "Fail" "" "" "Unknown PAM check_type: $check_type"
            ;;
    esac
}

# Apply a PAM control
handler_pam_apply() {
    local control_json="$1"
    local id title check_type

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    check_type="$(ctl_field "$control_json" "check_type")"

    case "$check_type" in
        faillock)
            _pam_apply_faillock "$control_json"
            ;;
        pwquality)
            _pam_apply_pwquality "$control_json"
            ;;
        config)
            handler_file_content_apply "$control_json"
            ;;
        *)
            emit_result "$id" "$title" "Fail" "" "" "Unknown PAM check_type: $check_type"
            ;;
    esac
}

# --- Faillock checks ---

_pam_audit_faillock() {
    local control_json="$1"
    local id title directive expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    directive="$(ctl_field "$control_json" "directive")"
    expected="$(ctl_field "$control_json" "expected")"

    # Check if faillock is enabled
    if ! distro_pam_faillock_enabled; then
        emit_result "$id" "$title" "Fail" "faillock enabled" "not enabled" "pam_faillock not configured"
        return
    fi

    # Check faillock.conf for the directive
    local faillock_conf="/etc/security/faillock.conf"
    if [[ -f "$faillock_conf" ]]; then
        local actual
        actual="$(grep -E "^\s*${directive}\s*=" "$faillock_conf" 2>/dev/null | tail -1 | sed -E 's/.*=\s*//' | xargs)" || actual=""
        if [[ "$actual" == "$expected" ]]; then
            emit_result "$id" "$title" "Pass" "$expected" "$actual" "faillock.conf: $directive"
        else
            emit_result "$id" "$title" "Fail" "$expected" "${actual:-not set}" "faillock.conf: $directive"
        fi
    else
        emit_result "$id" "$title" "Fail" "$expected" "file missing" "faillock.conf not found"
    fi
}

_pam_apply_faillock() {
    local control_json="$1"
    local id title directive expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    directive="$(ctl_field "$control_json" "directive")"
    expected="$(ctl_field "$control_json" "expected")"

    local audit_result
    audit_result="$(_pam_audit_faillock "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c --arg d "[DRY RUN] Would set $directive = $expected in faillock.conf" '.detail = $d'
        return
    fi

    local faillock_conf="/etc/security/faillock.conf"
    mkdir -p "$(dirname "$faillock_conf")" 2>/dev/null || true
    if grep -qE "^\s*#?\s*${directive}\s*=" "$faillock_conf" 2>/dev/null; then
        sed -i -E "s|^\s*#?\s*${directive}\s*=.*|${directive} = ${expected}|" "$faillock_conf"
    else
        echo "${directive} = ${expected}" >> "$faillock_conf"
    fi

    emit_result "$id" "$title" "Pass" "$expected" "$expected" "Set $directive = $expected in faillock.conf"
}

# --- Password quality checks ---

_pam_audit_pwquality() {
    local control_json="$1"
    local id title directive expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    directive="$(ctl_field "$control_json" "directive")"
    expected="$(ctl_field "$control_json" "expected")"

    local pwquality_conf="/etc/security/pwquality.conf"
    if [[ ! -f "$pwquality_conf" ]]; then
        emit_result "$id" "$title" "Fail" "$expected" "file missing" "pwquality.conf not found"
        return
    fi

    local actual
    actual="$(grep -E "^\s*${directive}\s*=" "$pwquality_conf" 2>/dev/null | tail -1 | sed -E 's/.*=\s*//' | xargs)" || actual=""

    if [[ "$actual" == "$expected" ]]; then
        emit_result "$id" "$title" "Pass" "$expected" "$actual" "pwquality.conf: $directive"
    else
        emit_result "$id" "$title" "Fail" "$expected" "${actual:-not set}" "pwquality.conf: $directive"
    fi
}

_pam_apply_pwquality() {
    local control_json="$1"
    local id title directive expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    directive="$(ctl_field "$control_json" "directive")"
    expected="$(ctl_field "$control_json" "expected")"

    local audit_result
    audit_result="$(_pam_audit_pwquality "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c --arg d "[DRY RUN] Would set $directive = $expected in pwquality.conf" '.detail = $d'
        return
    fi

    local pwquality_conf="/etc/security/pwquality.conf"
    if grep -qE "^\s*#?\s*${directive}\s*=" "$pwquality_conf" 2>/dev/null; then
        sed -i -E "s|^\s*#?\s*${directive}\s*=.*|${directive} = ${expected}|" "$pwquality_conf"
    else
        echo "${directive} = ${expected}" >> "$pwquality_conf"
    fi

    emit_result "$id" "$title" "Pass" "$expected" "$expected" "Set $directive = $expected in pwquality.conf"
}
