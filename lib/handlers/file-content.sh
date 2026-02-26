#!/usr/bin/env bash
# lib/handlers/file-content.sh — Audit and apply config file directives

# Audit a file-content control
# Input: JSON with fields: id, title, file, directive, expected, separator (default " "), match (exact/contains/regex)
handler_file_content_audit() {
    local control_json="$1"
    local id title file directive expected separator match

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    file="$(ctl_field "$control_json" "file")"
    directive="$(ctl_field "$control_json" "directive")"
    expected="$(ctl_field "$control_json" "expected")"
    separator="$(ctl_field "$control_json" "separator")"
    match="$(ctl_field "$control_json" "match")"

    separator="${separator:- }"
    match="${match:-exact}"

    if [[ ! -f "$file" ]]; then
        emit_result "$id" "$title" "Fail" "$expected" "file not found" "File $file does not exist"
        return
    fi

    # Find the active (non-commented) directive line
    local actual=""
    local line
    # Handle config files that may have Include directives (e.g., sshd_config.d/)
    # For now, check the main file. Handlers for sshd_config also check .d/ files.
    line="$(grep -Ei "^\s*${directive}\s*${separator}" "$file" 2>/dev/null | tail -1)" || true

    if [[ -z "$line" ]]; then
        emit_result "$id" "$title" "Fail" "${directive}${separator}${expected}" "not set" "Directive '$directive' not found in $file"
        return
    fi

    # Extract the value after the directive + separator
    actual="$(echo "$line" | sed -E "s/^\s*${directive}\s*${separator}\s*//" | xargs)"

    case "$match" in
        exact)
            if [[ "$actual" == "$expected" ]]; then
                emit_result "$id" "$title" "Pass" "$expected" "$actual" "$file: $directive"
            else
                emit_result "$id" "$title" "Fail" "$expected" "$actual" "$file: $directive"
            fi
            ;;
        contains)
            if echo "$actual" | grep -qi "$expected"; then
                emit_result "$id" "$title" "Pass" "$expected" "$actual" "$file: $directive"
            else
                emit_result "$id" "$title" "Fail" "$expected" "$actual" "$file: $directive"
            fi
            ;;
        regex)
            if echo "$actual" | grep -qE "$expected"; then
                emit_result "$id" "$title" "Pass" "$expected" "$actual" "$file: $directive"
            else
                emit_result "$id" "$title" "Fail" "$expected" "$actual" "$file: $directive"
            fi
            ;;
    esac
}

# Apply a file-content control
handler_file_content_apply() {
    local control_json="$1"
    local id title file directive expected separator

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    file="$(ctl_field "$control_json" "file")"
    directive="$(ctl_field "$control_json" "directive")"
    expected="$(ctl_field "$control_json" "expected")"
    separator="$(ctl_field "$control_json" "separator")"

    separator="${separator:- }"

    # Run audit first to check
    local audit_result
    audit_result="$(handler_file_content_audit "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c --arg d "[DRY RUN] Would set ${directive}${separator}${expected} in ${file}" '.detail = $d'
        return
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$file")" 2>/dev/null || true

    if [[ ! -f "$file" ]]; then
        # Create the file with the directive
        echo "${directive}${separator}${expected}" > "$file"
    elif grep -qEi "^\s*#?\s*${directive}\s" "$file" 2>/dev/null; then
        # Update existing (possibly commented) directive
        sed -i -E "s|^\s*#?\s*${directive}\s.*|${directive}${separator}${expected}|" "$file"
    else
        # Append new directive
        echo "${directive}${separator}${expected}" >> "$file"
    fi

    emit_result "$id" "$title" "Pass" "$expected" "$expected" "Set ${directive}${separator}${expected} in $file"
}
