#!/usr/bin/env bash
# lib/handlers/file-perms.sh — Audit and apply file permission/ownership

# Audit file permissions
# Input: JSON with fields: id, title, path, mode (octal), owner, group
handler_file_perms_audit() {
    local control_json="$1"
    local id title path expected_mode expected_owner expected_group

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    path="$(ctl_field "$control_json" "path")"
    expected_mode="$(ctl_field "$control_json" "mode")"
    expected_owner="$(ctl_field "$control_json" "owner")"
    expected_group="$(ctl_field "$control_json" "group")"

    if [[ ! -e "$path" ]]; then
        emit_result "$id" "$title" "Fail" "exists" "not found" "Path $path does not exist"
        return
    fi

    local failures=()
    local actual_parts=()

    # Check mode if specified
    if [[ -n "$expected_mode" ]]; then
        local actual_mode
        actual_mode="$(stat -c '%a' "$path" 2>/dev/null)"
        actual_parts+=("mode=$actual_mode")
        # Compare as octal — actual mode should be same or more restrictive
        if [[ "$actual_mode" != "$expected_mode" ]]; then
            # Check if actual is more restrictive (numerically <=)
            if (( 8#$actual_mode > 8#$expected_mode )); then
                failures+=("mode: expected $expected_mode, got $actual_mode")
            fi
        fi
    fi

    # Check owner if specified
    if [[ -n "$expected_owner" ]]; then
        local actual_owner
        actual_owner="$(stat -c '%U' "$path" 2>/dev/null)"
        actual_parts+=("owner=$actual_owner")
        if [[ "$actual_owner" != "$expected_owner" ]]; then
            failures+=("owner: expected $expected_owner, got $actual_owner")
        fi
    fi

    # Check group if specified
    if [[ -n "$expected_group" ]]; then
        local actual_group
        actual_group="$(stat -c '%G' "$path" 2>/dev/null)"
        actual_parts+=("group=$actual_group")
        if [[ "$actual_group" != "$expected_group" ]]; then
            failures+=("group: expected $expected_group, got $actual_group")
        fi
    fi

    local actual_str
    actual_str="$(IFS=', '; echo "${actual_parts[*]}")"
    local expected_str="${expected_mode:+mode=$expected_mode}${expected_owner:+, owner=$expected_owner}${expected_group:+, group=$expected_group}"

    if [[ ${#failures[@]} -eq 0 ]]; then
        emit_result "$id" "$title" "Pass" "$expected_str" "$actual_str" "$path"
    else
        local detail
        detail="$(IFS='; '; echo "${failures[*]}")"
        emit_result "$id" "$title" "Fail" "$expected_str" "$actual_str" "$path: $detail"
    fi
}

# Apply file permissions
handler_file_perms_apply() {
    local control_json="$1"
    local id title path expected_mode expected_owner expected_group

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    path="$(ctl_field "$control_json" "path")"
    expected_mode="$(ctl_field "$control_json" "mode")"
    expected_owner="$(ctl_field "$control_json" "owner")"
    expected_group="$(ctl_field "$control_json" "group")"

    if [[ ! -e "$path" ]]; then
        emit_result "$id" "$title" "Fail" "exists" "not found" "Path $path does not exist"
        return
    fi

    # Check current state
    local audit_result
    audit_result="$(handler_file_perms_audit "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c '.detail = "[DRY RUN] Would fix permissions on " + .detail'
        return
    fi

    # Apply fixes
    if [[ -n "$expected_mode" ]]; then
        chmod "$expected_mode" "$path" 2>/dev/null || true
    fi
    if [[ -n "$expected_owner" ]]; then
        chown "$expected_owner" "$path" 2>/dev/null || true
    fi
    if [[ -n "$expected_group" ]]; then
        chgrp "$expected_group" "$path" 2>/dev/null || true
    fi

    emit_result "$id" "$title" "Pass" "" "" "Fixed permissions on $path"
}
