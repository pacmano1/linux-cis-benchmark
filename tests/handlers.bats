#!/usr/bin/env bats
# tests/handlers.bats — Test handler dispatch and emit_result

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$REPO_ROOT/lib/core/log.sh"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/core/config.sh"
    LOG_LEVEL="ERROR"
}

@test "emit_result produces valid NDJSON" {
    local result
    result=$(emit_result "1.1.1" "Test control" "Pass" "expected" "actual" "detail")
    echo "$result" | jq '.' > /dev/null || fail "Invalid JSON: $result"
}

@test "emit_result includes all fields" {
    local result
    result=$(emit_result "1.1.1" "Test control" "Pass" "expected" "actual" "some detail")

    local id
    id=$(echo "$result" | jq -r '.id')
    [ "$id" = "1.1.1" ]

    local status
    status=$(echo "$result" | jq -r '.status')
    [ "$status" = "Pass" ]

    local detail
    detail=$(echo "$result" | jq -r '.detail')
    [ "$detail" = "some detail" ]
}

@test "emit_result handles special characters in JSON" {
    local result
    result=$(emit_result "1.1.1" "Test \"quoted\" control" "Fail" "val with spaces" 'path/with/slashes' 'detail with "quotes"')
    echo "$result" | jq '.' > /dev/null || fail "Invalid JSON with special chars: $result"
}

@test "emit_skipped produces Skip status" {
    local result
    result=$(emit_skipped "1.1.1" "Skipped control" "Because reasons")

    local status
    status=$(echo "$result" | jq -r '.status')
    [ "$status" = "Skip" ]

    local detail
    detail=$(echo "$result" | jq -r '.detail')
    [ "$detail" = "Because reasons" ]
}

@test "ctl_field extracts JSON fields" {
    local json='{"id":"1.1.1","title":"Test","type":"sysctl","key":"net.ipv4.ip_forward"}'

    local id
    id=$(ctl_field "$json" "id")
    [ "$id" = "1.1.1" ]

    local handler_type
    handler_type=$(ctl_field "$json" "type")
    [ "$handler_type" = "sysctl" ]

    local key
    key=$(ctl_field "$json" "key")
    [ "$key" = "net.ipv4.ip_forward" ]
}

@test "ctl_field returns empty for missing fields" {
    local json='{"id":"1.1.1"}'
    local missing
    missing=$(ctl_field "$json" "nonexistent")
    [ -z "$missing" ]
}

@test "read_controls extracts controls from JSON file" {
    local count
    count=$(read_controls "$REPO_ROOT/config/modules/3-network.json" | wc -l | tr -d ' ')
    [ "$count" -eq 30 ]
}

@test "is_control_skipped works with skip list" {
    _SKIP_IDS=$'1.1.1\n1.1.2\n1.1.3'

    is_control_skipped "1.1.1"
    ! is_control_skipped "2.1.1"
}

@test "apply_modifications applies field overrides" {
    _MODIFY_JSON='{"5.1.5":{"field":"expected","value":"prohibit-password","reason":"test"}}'

    local control='{"id":"5.1.5","title":"SSH root login","type":"file-content","expected":"no"}'
    local modified
    modified=$(apply_modifications "$control")

    local expected
    expected=$(echo "$modified" | jq -r '.expected')
    [ "$expected" = "prohibit-password" ]
}

@test "apply_modifications passes through unmodified controls" {
    _MODIFY_JSON='{}'

    local control='{"id":"1.1.1","title":"Test","type":"sysctl","expected":"0"}'
    local result
    result=$(apply_modifications "$control")

    local expected
    expected=$(echo "$result" | jq -r '.expected')
    [ "$expected" = "0" ]
}

@test "resolve_control skips controls in skip list" {
    _SKIP_IDS="1.1.1"
    _SKIP_REASONS='{"1.1.1":"Test skip"}'
    _MODIFY_JSON='{}'

    local control='{"id":"1.1.1","title":"Test","type":"sysctl"}'
    local result
    result=$(resolve_control "$control")
    local rc=$?

    [ "$rc" -ne 0 ]  # should return non-zero (skipped)

    local status
    status=$(echo "$result" | jq -r '.status')
    [ "$status" = "Skip" ]
}

@test "resolve_control skips wrong distro_only" {
    _SKIP_IDS=""
    _MODIFY_JSON='{}'
    DISTRO_ID="ubuntu2404"

    local control='{"id":"1.3.1.1","title":"SELinux","type":"mac","distro_only":"rhel9"}'
    local result
    result=$(resolve_control "$control")
    local rc=$?

    [ "$rc" -ne 0 ]
    local status
    status=$(echo "$result" | jq -r '.status')
    [ "$status" = "Skip" ]
}

@test "resolve_control passes matching distro_only" {
    _SKIP_IDS=""
    _MODIFY_JSON='{}'
    DISTRO_ID="rhel9"

    local control='{"id":"1.3.1.1","title":"SELinux","type":"mac","distro_only":"rhel9","check_type":"installed"}'
    local result
    result=$(resolve_control "$control")
    local rc=$?

    [ "$rc" -eq 0 ]
}
