#!/usr/bin/env bash
# lib/modules/module-dispatch.sh — Generic module dispatch logic
# Shared by all module orchestrators

# Process all controls in a module config for audit
# Usage: dispatch_audit "config_file.json"
dispatch_audit() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    local control_count
    control_count="$(jq '.controls | length' "$config_file")"
    if (( control_count == 0 )); then
        log_debug "No controls in $config_file"
        return 0
    fi

    while IFS= read -r raw_control; do
        [[ -z "$raw_control" ]] && continue

        # Resolve control (check skip, distro, mods)
        local resolved
        resolved="$(resolve_control "$raw_control")" || continue

        local handler_type
        handler_type="$(ctl_field "$resolved" "type")"

        if [[ -z "$handler_type" ]]; then
            local ctl_id
            ctl_id="$(ctl_field "$resolved" "id")"
            log_warn "Control $ctl_id has no type field"
            continue
        fi

        # Normalize type for function name (replace - with _)
        local func_name="handler_${handler_type//-/_}_audit"

        if declare -f "$func_name" &>/dev/null; then
            "$func_name" "$resolved"
        else
            local ctl_id ctl_title
            ctl_id="$(ctl_field "$resolved" "id")"
            ctl_title="$(ctl_field "$resolved" "title")"
            log_warn "No handler function: $func_name for control $ctl_id"
            emit_result "$ctl_id" "$ctl_title" "Skip" "" "" "No handler for type: $handler_type"
        fi
    done < <(jq -c '.controls[]' "$config_file")
}

# Process all controls in a module config for apply
# Usage: dispatch_apply "config_file.json"
dispatch_apply() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    local control_count
    control_count="$(jq '.controls | length' "$config_file")"
    if (( control_count == 0 )); then
        log_debug "No controls in $config_file"
        return 0
    fi

    while IFS= read -r raw_control; do
        [[ -z "$raw_control" ]] && continue

        local resolved
        resolved="$(resolve_control "$raw_control")" || continue

        local handler_type
        handler_type="$(ctl_field "$resolved" "type")"

        if [[ -z "$handler_type" ]]; then
            continue
        fi

        local func_name="handler_${handler_type//-/_}_apply"

        if declare -f "$func_name" &>/dev/null; then
            "$func_name" "$resolved"
        else
            local ctl_id ctl_title
            ctl_id="$(ctl_field "$resolved" "id")"
            ctl_title="$(ctl_field "$resolved" "title")"
            log_warn "No apply handler: $func_name for control $ctl_id"
            emit_result "$ctl_id" "$ctl_title" "Skip" "" "" "No apply handler for type: $handler_type"
        fi
    done < <(jq -c '.controls[]' "$config_file")
}
