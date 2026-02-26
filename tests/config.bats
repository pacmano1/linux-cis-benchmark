#!/usr/bin/env bats
# tests/config.bats — Test configuration loading

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    # Source core libs directly (skip distro detection for unit tests)
    source "$REPO_ROOT/lib/core/log.sh"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/core/config.sh"

    LOG_LEVEL="ERROR"  # Suppress log output during tests
}

@test "master.conf exists and is sourceable" {
    source "$REPO_ROOT/config/master.conf"
    [ "$DRY_RUN" = "true" ]
    [ "$LOG_LEVEL" = "INFO" ] || [ "$LOG_LEVEL" = "ERROR" ]
}

@test "master.conf enables all modules by default" {
    source "$REPO_ROOT/config/master.conf"
    [ "$MODULE_1_INITIAL_SETUP" = "1" ]
    [ "$MODULE_2_SERVICES" = "1" ]
    [ "$MODULE_3_NETWORK" = "1" ]
    [ "$MODULE_4_FIREWALL" = "1" ]
    [ "$MODULE_5_ACCESS_CONTROL" = "1" ]
    [ "$MODULE_6_LOGGING" = "1" ]
    [ "$MODULE_7_MAINTENANCE" = "1" ]
}

@test "aws-exclusions.json is valid JSON" {
    jq '.' "$REPO_ROOT/config/aws-exclusions.json" > /dev/null
}

@test "aws-exclusions.json has skip array and modify object" {
    local skip_count
    skip_count=$(jq '.skip | length' "$REPO_ROOT/config/aws-exclusions.json")
    [ "$skip_count" -gt 0 ]

    local modify_type
    modify_type=$(jq -r '.modify | type' "$REPO_ROOT/config/aws-exclusions.json")
    [ "$modify_type" = "object" ]
}

@test "all module JSON files are valid" {
    for f in "$REPO_ROOT"/config/modules/*.json; do
        jq '.' "$f" > /dev/null 2>&1 || fail "Invalid JSON: $f"
    done
}

@test "all module JSON files have section, title, and controls array" {
    for f in "$REPO_ROOT"/config/modules/*.json; do
        local section
        section=$(jq -r '.section' "$f")
        [ -n "$section" ] || fail "Missing section in $f"

        local title
        title=$(jq -r '.title' "$f")
        [ -n "$title" ] || fail "Missing title in $f"

        local controls_type
        controls_type=$(jq -r '.controls | type' "$f")
        [ "$controls_type" = "array" ] || fail "Controls not an array in $f"
    done
}

@test "all controls have id, title, and type fields" {
    for f in "$REPO_ROOT"/config/modules/*.json; do
        local bad
        bad=$(jq -r '.controls[] | select(.id == null or .title == null or .type == null) | .id // "unknown"' "$f")
        [ -z "$bad" ] || fail "Control(s) missing id/title/type in $f: $bad"
    done
}

@test "total control count is 264" {
    local total=0
    for f in "$REPO_ROOT"/config/modules/*.json; do
        local count
        count=$(jq '.controls | length' "$f")
        total=$((total + count))
    done
    [ "$total" -eq 264 ]
}

@test "get_enabled_modules returns all 7 by default" {
    source "$REPO_ROOT/config/master.conf"
    local modules
    modules=$(get_enabled_modules)
    [ "$modules" = "1 2 3 4 5 6 7" ]
}

@test "module_config_file returns correct paths" {
    local path
    path=$(module_config_file 1)
    [[ "$path" == *"1-initial-setup.json" ]]

    path=$(module_config_file 7)
    [[ "$path" == *"7-maintenance.json" ]]
}

@test "module_name returns correct names" {
    local name
    name=$(module_name 1)
    [ "$name" = "Initial Setup" ]

    name=$(module_name 5)
    [ "$name" = "Access, Authentication and Authorization" ]
}

@test "distro config files are sourceable" {
    source "$REPO_ROOT/config/distro/rhel9.conf"
    [ "$DISTRO_ID" = "rhel9" ]
    [ "$PKG_MANAGER" = "dnf" ]

    source "$REPO_ROOT/config/distro/ubuntu2404.conf"
    [ "$DISTRO_ID" = "ubuntu2404" ]
    [ "$PKG_MANAGER" = "apt" ]
}
