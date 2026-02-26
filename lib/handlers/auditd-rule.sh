#!/usr/bin/env bash
# lib/handlers/auditd-rule.sh — Audit and apply auditd rules

# Audit an auditd rule control
# Input: JSON with fields: id, title, rule (full auditd rule string), match_pattern (regex for checking)
handler_auditd_rule_audit() {
    local control_json="$1"
    local id title rule match_pattern

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    rule="$(ctl_field "$control_json" "rule")"
    match_pattern="$(ctl_field "$control_json" "match_pattern")"

    # Use match_pattern if provided, otherwise use the rule itself as a pattern
    local pattern="${match_pattern:-$rule}"

    # Check if auditd is installed
    if ! command_exists auditctl; then
        emit_result "$id" "$title" "Fail" "rule configured" "auditctl not found" "auditd is not installed"
        return
    fi

    # Check loaded rules
    local loaded_rules
    loaded_rules="$(auditctl -l 2>/dev/null)" || loaded_rules=""

    # Check on-disk rules
    local disk_rules=""
    for rules_file in /etc/audit/rules.d/*.rules; do
        if [[ -f "$rules_file" ]]; then
            disk_rules+="$(cat "$rules_file")"$'\n'
        fi
    done

    local in_loaded=false
    local in_disk=false

    if echo "$loaded_rules" | grep -qE "$pattern"; then
        in_loaded=true
    fi
    if echo "$disk_rules" | grep -qE "$pattern"; then
        in_disk=true
    fi

    if [[ "$in_loaded" == true && "$in_disk" == true ]]; then
        emit_result "$id" "$title" "Pass" "rule configured" "loaded + on disk" "Rule: $rule"
    elif [[ "$in_disk" == true ]]; then
        emit_result "$id" "$title" "Fail" "rule loaded" "on disk only" "Rule is on disk but not loaded (restart auditd)"
    else
        emit_result "$id" "$title" "Fail" "rule configured" "not found" "Rule missing: $rule"
    fi
}

# Apply an auditd rule
handler_auditd_rule_apply() {
    local control_json="$1"
    local id title rule rule_file

    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"
    rule="$(ctl_field "$control_json" "rule")"
    rule_file="$(ctl_field "$control_json" "rule_file")"

    rule_file="${rule_file:-/etc/audit/rules.d/cis-benchmark.rules}"

    # Check current state
    local audit_result
    audit_result="$(handler_auditd_rule_audit "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c --arg d "[DRY RUN] Would add audit rule: $rule" '.detail = $d'
        return
    fi

    # Ensure rules directory exists
    mkdir -p "$(dirname "$rule_file")" 2>/dev/null || true

    # Add rule to file if not already present
    if ! grep -qF "$rule" "$rule_file" 2>/dev/null; then
        echo "$rule" >> "$rule_file"
    fi

    # Load the rule immediately
    auditctl -w "$rule" 2>/dev/null || augenrules --load 2>/dev/null || true

    emit_result "$id" "$title" "Pass" "rule configured" "applied" "Added audit rule: $rule"
}
