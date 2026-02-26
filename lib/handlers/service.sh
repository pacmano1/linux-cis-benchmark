#!/usr/bin/env bash
# lib/handlers/service.sh — Audit and apply systemctl service state

# Audit a service control
# Input: JSON control with fields: id, title, service, expected (enabled/disabled/not_installed/masked)
handler_service_audit() {
    local control_json="$1"
    local id title service expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    service="$(ctl_field "$control_json" "service")"
    expected="$(ctl_field "$control_json" "expected")"

    local actual=""

    case "$expected" in
        not_installed)
            # Service/package should not be installed
            if systemctl list-unit-files "${service}.service" 2>/dev/null | grep -q "${service}"; then
                actual="installed"
                emit_result "$id" "$title" "Fail" "not_installed" "$actual" "Service $service is present"
            else
                actual="not_installed"
                emit_result "$id" "$title" "Pass" "not_installed" "$actual" "Service $service is not installed"
            fi
            ;;
        disabled)
            if ! systemctl is-enabled "$service" &>/dev/null; then
                actual="disabled"
            else
                actual="$(systemctl is-enabled "$service" 2>/dev/null)"
            fi
            if [[ "$actual" == "disabled" || "$actual" == "masked" || "$actual" == "not-found" ]]; then
                emit_result "$id" "$title" "Pass" "disabled" "$actual" "Service $service"
            else
                emit_result "$id" "$title" "Fail" "disabled" "$actual" "Service $service is $actual"
            fi
            ;;
        masked)
            actual="$(systemctl is-enabled "$service" 2>/dev/null || echo "not-found")"
            if [[ "$actual" == "masked" ]]; then
                emit_result "$id" "$title" "Pass" "masked" "$actual" "Service $service"
            else
                emit_result "$id" "$title" "Fail" "masked" "$actual" "Service $service is $actual"
            fi
            ;;
        enabled)
            actual="$(systemctl is-enabled "$service" 2>/dev/null || echo "not-found")"
            if [[ "$actual" == "enabled" ]]; then
                emit_result "$id" "$title" "Pass" "enabled" "$actual" "Service $service"
            else
                emit_result "$id" "$title" "Fail" "enabled" "$actual" "Service $service is $actual"
            fi
            ;;
        active)
            if systemctl is-active "$service" &>/dev/null; then
                emit_result "$id" "$title" "Pass" "active" "active" "Service $service"
            else
                actual="$(systemctl is-active "$service" 2>/dev/null || echo "inactive")"
                emit_result "$id" "$title" "Fail" "active" "$actual" "Service $service"
            fi
            ;;
    esac
}

# Apply a service control
handler_service_apply() {
    local control_json="$1"
    local id title service expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    service="$(ctl_field "$control_json" "service")"
    expected="$(ctl_field "$control_json" "expected")"

    # First check current state
    local actual
    actual="$(systemctl is-enabled "$service" 2>/dev/null || echo "not-found")"

    case "$expected" in
        disabled)
            if [[ "$actual" == "disabled" || "$actual" == "masked" || "$actual" == "not-found" ]]; then
                emit_result "$id" "$title" "Pass" "disabled" "$actual" "Already disabled"
                return
            fi
            if [[ "${DRY_RUN:-true}" == "true" ]]; then
                emit_result "$id" "$title" "Fail" "disabled" "$actual" "[DRY RUN] Would disable $service"
                return
            fi
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "disabled" "disabled" "Disabled $service"
            ;;
        masked)
            if [[ "$actual" == "masked" ]]; then
                emit_result "$id" "$title" "Pass" "masked" "$actual" "Already masked"
                return
            fi
            if [[ "${DRY_RUN:-true}" == "true" ]]; then
                emit_result "$id" "$title" "Fail" "masked" "$actual" "[DRY RUN] Would mask $service"
                return
            fi
            systemctl stop "$service" 2>/dev/null || true
            systemctl mask "$service" 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "masked" "masked" "Masked $service"
            ;;
        enabled)
            if [[ "$actual" == "enabled" ]]; then
                emit_result "$id" "$title" "Pass" "enabled" "$actual" "Already enabled"
                return
            fi
            if [[ "${DRY_RUN:-true}" == "true" ]]; then
                emit_result "$id" "$title" "Fail" "enabled" "$actual" "[DRY RUN] Would enable $service"
                return
            fi
            systemctl enable "$service" 2>/dev/null || true
            systemctl start "$service" 2>/dev/null || true
            emit_result "$id" "$title" "Pass" "enabled" "enabled" "Enabled $service"
            ;;
    esac
}
