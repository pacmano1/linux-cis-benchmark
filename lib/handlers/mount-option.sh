#!/usr/bin/env bash
# lib/handlers/mount-option.sh — Audit and apply fstab mount options

# Audit mount options
# Input: JSON with fields: id, title, mount_point, options (array of required options like nodev, nosuid, noexec)
handler_mount_option_audit() {
    local control_json="$1"
    local id title mount_point

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    mount_point="$(ctl_field "$control_json" "mount_point")"

    # Get required options as array
    local options_json
    options_json="$(echo "$control_json" | jq -r '.options[]? // empty')"

    if [[ -z "$options_json" ]]; then
        emit_result "$id" "$title" "Fail" "options defined" "no options" "No options specified in control"
        return
    fi

    # Check if mount point exists
    if ! findmnt -n "$mount_point" &>/dev/null; then
        # Check if it's in fstab at all
        if grep -qE "^\s*[^#]\S+\s+${mount_point}\s" /etc/fstab 2>/dev/null; then
            emit_result "$id" "$title" "Fail" "mounted" "in fstab but not mounted" "$mount_point"
        else
            emit_result "$id" "$title" "Fail" "mounted" "not configured" "$mount_point not in fstab"
        fi
        return
    fi

    local current_options
    current_options="$(findmnt -n -o OPTIONS "$mount_point" 2>/dev/null)"

    local missing=()
    while IFS= read -r opt; do
        [[ -z "$opt" ]] && continue
        if ! echo ",$current_options," | grep -q ",${opt},"; then
            missing+=("$opt")
        fi
    done <<< "$options_json"

    if [[ ${#missing[@]} -eq 0 ]]; then
        emit_result "$id" "$title" "Pass" "$(echo "$options_json" | tr '\n' ',')" "$current_options" "$mount_point"
    else
        emit_result "$id" "$title" "Fail" "$(echo "$options_json" | tr '\n' ',')" "$current_options" "$mount_point: missing $(IFS=','; echo "${missing[*]}")"
    fi
}

# Apply mount options
handler_mount_option_apply() {
    local control_json="$1"
    local id title mount_point

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    mount_point="$(ctl_field "$control_json" "mount_point")"

    # Check current state
    local audit_result
    audit_result="$(handler_mount_option_audit "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c '.detail = "[DRY RUN] Would add mount options to " + .detail'
        return
    fi

    # Get options to add
    local options_json
    options_json="$(echo "$control_json" | jq -r '.options[]? // empty')"

    # Modify fstab entry
    if grep -qE "^\s*[^#]\S+\s+${mount_point}\s" /etc/fstab 2>/dev/null; then
        local current_opts
        current_opts="$(awk -v mp="$mount_point" '$2 == mp && $0 !~ /^#/ {print $4}' /etc/fstab)"
        local new_opts="$current_opts"
        while IFS= read -r opt; do
            [[ -z "$opt" ]] && continue
            if ! echo ",$new_opts," | grep -q ",${opt},"; then
                new_opts="${new_opts},${opt}"
            fi
        done <<< "$options_json"
        sed -i -E "s|(^\s*\S+\s+${mount_point}\s+\S+\s+)\S+|\1${new_opts}|" /etc/fstab
        # Remount
        mount -o remount "$mount_point" 2>/dev/null || true
    fi

    emit_result "$id" "$title" "Pass" "" "" "Updated mount options for $mount_point"
}
