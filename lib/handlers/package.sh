#!/usr/bin/env bash
# lib/handlers/package.sh — Audit and apply package install/remove

# Audit a package control
# Input: JSON control with fields: id, title, package, expected (installed/not_installed)
handler_package_audit() {
    local control_json="$1"
    local id title package expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    package="$(ctl_field "$control_json" "package")"
    expected="$(ctl_field "$control_json" "expected")"

    local is_installed=false
    if distro_pkg_installed "$package"; then
        is_installed=true
    fi

    case "$expected" in
        installed)
            if [[ "$is_installed" == true ]]; then
                emit_result "$id" "$title" "Pass" "installed" "installed" "Package $package"
            else
                emit_result "$id" "$title" "Fail" "installed" "not_installed" "Package $package is not installed"
            fi
            ;;
        not_installed)
            if [[ "$is_installed" == false ]]; then
                emit_result "$id" "$title" "Pass" "not_installed" "not_installed" "Package $package"
            else
                emit_result "$id" "$title" "Fail" "not_installed" "installed" "Package $package should be removed"
            fi
            ;;
    esac
}

# Apply a package control
handler_package_apply() {
    local control_json="$1"
    local id title package expected

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    package="$(ctl_field "$control_json" "package")"
    expected="$(ctl_field "$control_json" "expected")"

    local is_installed=false
    if distro_pkg_installed "$package"; then
        is_installed=true
    fi

    case "$expected" in
        installed)
            if [[ "$is_installed" == true ]]; then
                emit_result "$id" "$title" "Pass" "installed" "installed" "Already installed"
                return
            fi
            if [[ "${DRY_RUN:-true}" == "true" ]]; then
                emit_result "$id" "$title" "Fail" "installed" "not_installed" "[DRY RUN] Would install $package"
                return
            fi
            distro_pkg_install "$package"
            emit_result "$id" "$title" "Pass" "installed" "installed" "Installed $package"
            ;;
        not_installed)
            if [[ "$is_installed" == false ]]; then
                emit_result "$id" "$title" "Pass" "not_installed" "not_installed" "Already absent"
                return
            fi
            if [[ "${DRY_RUN:-true}" == "true" ]]; then
                emit_result "$id" "$title" "Fail" "not_installed" "installed" "[DRY RUN] Would remove $package"
                return
            fi
            distro_pkg_remove "$package"
            emit_result "$id" "$title" "Pass" "not_installed" "not_installed" "Removed $package"
            ;;
    esac
}
