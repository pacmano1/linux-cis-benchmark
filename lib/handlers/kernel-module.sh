#!/usr/bin/env bash
# lib/handlers/kernel-module.sh — Audit and apply kernel module blacklisting

# Check if a kernel module is disabled (blacklisted/install false)
_kmod_is_disabled() {
    local module="$1"

    # Check if module is blacklisted
    local blacklisted=false
    if grep -rqs "^blacklist\s\+${module}" /etc/modprobe.d/ 2>/dev/null; then
        blacklisted=true
    fi

    # Check if install is set to /bin/false or /bin/true
    local install_false=false
    if grep -rqs "^install\s\+${module}\s\+/bin/\(false\|true\)" /etc/modprobe.d/ 2>/dev/null; then
        install_false=true
    fi

    # Check if module is currently loaded
    local loaded=false
    if lsmod 2>/dev/null | grep -q "^${module}\b"; then
        loaded=true
    fi

    if [[ "$blacklisted" == true && "$install_false" == true && "$loaded" == false ]]; then
        return 0
    fi
    return 1
}

# Audit a kernel module control
# Input: JSON control with fields: id, title, module, action (disable/ensure_loaded)
handler_kernel_module_audit() {
    local control_json="$1"
    local id title module action

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    module="$(ctl_field "$control_json" "module")"
    action="$(ctl_field "$control_json" "action")"

    if [[ "${action:-disable}" == "disable" ]]; then
        if _kmod_is_disabled "$module"; then
            emit_result "$id" "$title" "Pass" "disabled" "disabled" "Module $module is blacklisted and not loaded"
        else
            local detail=""
            if lsmod 2>/dev/null | grep -q "^${module}\b"; then
                detail="Module $module is currently loaded"
            else
                detail="Module $module is not properly blacklisted"
            fi
            emit_result "$id" "$title" "Fail" "disabled" "not disabled" "$detail"
        fi
    elif [[ "$action" == "ensure_loaded" ]]; then
        if lsmod 2>/dev/null | grep -q "^${module}\b"; then
            emit_result "$id" "$title" "Pass" "loaded" "loaded" "Module $module is loaded"
        else
            emit_result "$id" "$title" "Fail" "loaded" "not loaded" "Module $module is not loaded"
        fi
    fi
}

# Apply a kernel module control
handler_kernel_module_apply() {
    local control_json="$1"
    local id title module action

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    module="$(ctl_field "$control_json" "module")"
    action="$(ctl_field "$control_json" "action")"

    if [[ "${action:-disable}" == "disable" ]]; then
        if _kmod_is_disabled "$module"; then
            emit_result "$id" "$title" "Pass" "disabled" "disabled" "Already disabled"
            return
        fi

        if [[ "${DRY_RUN:-true}" == "true" ]]; then
            emit_result "$id" "$title" "Fail" "disabled" "not disabled" "[DRY RUN] Would blacklist module $module"
            return
        fi

        # Create/update modprobe config
        local conf_file="/etc/modprobe.d/cis-${module}.conf"
        {
            echo "# CIS Benchmark — disable ${module}"
            echo "install ${module} /bin/false"
            echo "blacklist ${module}"
        } > "$conf_file"

        # Unload if currently loaded
        if lsmod 2>/dev/null | grep -q "^${module}\b"; then
            modprobe -r "$module" 2>/dev/null || true
        fi

        emit_result "$id" "$title" "Pass" "disabled" "disabled" "Blacklisted module $module"
    fi
}
