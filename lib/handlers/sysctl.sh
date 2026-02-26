#!/usr/bin/env bash
# lib/handlers/sysctl.sh — Audit and apply sysctl kernel parameters

# Audit a sysctl control
# Input: JSON control with fields: id, title, key, expected
handler_sysctl_audit() {
    local control_json="$1"
    local id title key expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    key="$(ctl_field "$control_json" "key")"
    expected="$(ctl_field "$control_json" "expected")"

    local actual
    actual="$(sysctl -n "$key" 2>/dev/null)" || actual=""

    if [[ "$actual" == "$expected" ]]; then
        emit_result "$id" "$title" "Pass" "$expected" "$actual" "sysctl $key"
    else
        emit_result "$id" "$title" "Fail" "$expected" "$actual" "sysctl $key"
    fi
}

# Apply a sysctl control
# Sets the value immediately and persists to /etc/sysctl.d/
handler_sysctl_apply() {
    local control_json="$1"
    local id title key expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    key="$(ctl_field "$control_json" "key")"
    expected="$(ctl_field "$control_json" "expected")"

    local actual
    actual="$(sysctl -n "$key" 2>/dev/null)" || actual=""

    if [[ "$actual" == "$expected" ]]; then
        emit_result "$id" "$title" "Pass" "$expected" "$actual" "Already set"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        emit_result "$id" "$title" "Fail" "$expected" "$actual" "[DRY RUN] Would set sysctl $key=$expected"
        return
    fi

    # Apply immediately
    sysctl -w "${key}=${expected}" &>/dev/null

    # Persist to /etc/sysctl.d/99-cis-benchmark.conf
    local persist_file="/etc/sysctl.d/99-cis-benchmark.conf"
    if grep -q "^${key}" "$persist_file" 2>/dev/null; then
        sed -i "s|^${key}.*|${key} = ${expected}|" "$persist_file"
    else
        echo "${key} = ${expected}" >> "$persist_file"
    fi

    emit_result "$id" "$title" "Pass" "$expected" "$expected" "Applied sysctl $key=$expected"
}
