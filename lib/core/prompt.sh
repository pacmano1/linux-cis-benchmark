#!/usr/bin/env bash
# lib/core/prompt.sh — Interactive prompts ([D/l] format, --force)
# Mirrors the Windows prompt pattern exactly

# Global: set to true by --force flag to skip all prompts
FORCE=false

# Prompt the user with a yes/no question
# Usage: prompt_yn "Question text" "default" → sets REPLY to y or n
# Default: y or n (uppercase letter in the prompt indicates default)
prompt_yn() {
    local question="$1"
    local default="${2:-n}"

    if [[ "$FORCE" == true ]]; then
        REPLY="$default"
        return 0
    fi

    local options
    if [[ "$default" == "y" ]]; then
        options="[Y/n]"
    else
        options="[y/N]"
    fi

    while true; do
        printf '  ? %s %s: ' "$question" "$options" >&2
        read -r REPLY
        REPLY="${REPLY:-$default}"
        REPLY="$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')"
        case "$REPLY" in
            y|yes) REPLY="y"; return 0 ;;
            n|no)  REPLY="n"; return 0 ;;
            *)     printf '    Please answer y or n.\n' >&2 ;;
        esac
    done
}

# Prompt for mode selection (dry-run / live)
# Usage: prompt_mode → sets REPLY to d or l
prompt_mode() {
    if [[ "$FORCE" == true ]]; then
        if [[ "${DRY_RUN:-true}" == "false" ]]; then
            REPLY="l"
        else
            REPLY="d"
        fi
        return 0
    fi

    while true; do
        printf '  ? Run mode? [D/l]: ' >&2
        read -r REPLY
        REPLY="${REPLY:-d}"
        REPLY="$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')"
        case "$REPLY" in
            d|dry|dryrun|dry-run) REPLY="d"; return 0 ;;
            l|live)               REPLY="l"; return 0 ;;
            *)                    printf '    Please answer d (dry run) or l (live).\n' >&2 ;;
        esac
    done
}

# Prompt for module selection (all / selective)
# Usage: prompt_modules → sets SELECTED_MODULES array
prompt_modules() {
    local available_modules
    available_modules=($(get_enabled_modules))

    if [[ "$FORCE" == true || ${#SELECTED_MODULES[@]} -gt 0 ]]; then
        # If SELECTED_MODULES was set via CLI, use it; otherwise use all enabled
        if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
            SELECTED_MODULES=("${available_modules[@]}")
        fi
        return 0
    fi

    printf '  ? Module selection? [A/s]: ' >&2
    read -r REPLY
    REPLY="${REPLY:-a}"
    REPLY="$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')"

    if [[ "$REPLY" == "a" || "$REPLY" == "all" ]]; then
        SELECTED_MODULES=("${available_modules[@]}")
        return 0
    fi

    # Selective: show numbered list
    printf '\n  Available modules:\n' >&2
    for num in "${available_modules[@]}"; do
        printf '    %d. %s\n' "$num" "$(module_name "$num")" >&2
    done
    printf '\n  Enter module numbers (comma-separated, e.g., 1,3,5): ' >&2
    read -r REPLY
    IFS=',' read -ra SELECTED_MODULES <<< "$REPLY"
    # Trim whitespace
    SELECTED_MODULES=("${SELECTED_MODULES[@]// /}")
}

# Prompt for live-mode confirmation (requires typing YES)
prompt_confirm_live() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi

    printf '\n' >&2
    printf '  %s*** LIVE MODE ***%s\n' "${COLOR_RED}" "${COLOR_RESET}" >&2
    printf '  This will modify system configuration.\n' >&2
    printf '  A backup will be created before any changes.\n' >&2
    printf '\n' >&2
    printf '  Type YES to confirm: ' >&2
    read -r REPLY
    if [[ "$REPLY" != "YES" ]]; then
        log_info "Live mode cancelled by user"
        exit 0
    fi
}
