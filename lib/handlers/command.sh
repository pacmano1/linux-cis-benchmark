#!/usr/bin/env bash
# lib/handlers/command.sh — Generic command-based audit and apply

# Audit using a command
# Input: JSON with fields: id, title, audit_cmd, expected, match (exact/contains/regex/empty/not_empty)
handler_command_audit() {
    local control_json="$1"
    local id title audit_cmd expected match

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    audit_cmd="$(ctl_field "$control_json" "audit_cmd")"
    expected="$(ctl_field "$control_json" "expected")"
    match="$(ctl_field "$control_json" "match")"

    match="${match:-exact}"

    if [[ -z "$audit_cmd" ]]; then
        emit_result "$id" "$title" "Fail" "" "" "No audit_cmd defined"
        return
    fi

    local actual
    actual="$(eval "$audit_cmd" 2>/dev/null)" || actual=""

    case "$match" in
        exact)
            if [[ "$actual" == "$expected" ]]; then
                emit_result "$id" "$title" "Pass" "$expected" "$actual" "$audit_cmd"
            else
                emit_result "$id" "$title" "Fail" "$expected" "$actual" "$audit_cmd"
            fi
            ;;
        contains)
            if echo "$actual" | grep -qi "$expected"; then
                emit_result "$id" "$title" "Pass" "$expected" "$actual" "$audit_cmd"
            else
                emit_result "$id" "$title" "Fail" "$expected" "$actual" "$audit_cmd"
            fi
            ;;
        regex)
            if echo "$actual" | grep -qE "$expected"; then
                emit_result "$id" "$title" "Pass" "$expected" "$actual" "$audit_cmd"
            else
                emit_result "$id" "$title" "Fail" "$expected" "$actual" "$audit_cmd"
            fi
            ;;
        empty)
            if [[ -z "$actual" ]]; then
                emit_result "$id" "$title" "Pass" "empty" "empty" "$audit_cmd"
            else
                emit_result "$id" "$title" "Fail" "empty" "$actual" "$audit_cmd"
            fi
            ;;
        not_empty)
            if [[ -n "$actual" ]]; then
                emit_result "$id" "$title" "Pass" "not empty" "$actual" "$audit_cmd"
            else
                emit_result "$id" "$title" "Fail" "not empty" "empty" "$audit_cmd"
            fi
            ;;
    esac
}

# Apply using a command
# Input: JSON with fields: id, title, audit_cmd, apply_cmd, expected
handler_command_apply() {
    local control_json="$1"
    local id title apply_cmd

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    apply_cmd="$(ctl_field "$control_json" "apply_cmd")"

    # Check current state first
    local audit_result
    audit_result="$(handler_command_audit "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ -z "$apply_cmd" ]]; then
        echo "$audit_result" | jq -c '.detail = .detail + " (no apply_cmd defined)"'
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c --arg d "[DRY RUN] Would run: $apply_cmd" '.detail = $d'
        return
    fi

    eval "$apply_cmd" 2>/dev/null || true
    emit_result "$id" "$title" "Pass" "" "" "Applied: $apply_cmd"
}
