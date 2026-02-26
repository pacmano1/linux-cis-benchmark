#!/usr/bin/env bats
# tests/integration.bats — Integration tests for the full framework

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    TEST_DIR=$(mktemp -d "$BATS_TMPDIR/cis-test-XXXXXX")
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "all shell scripts have valid bash syntax" {
    local errors=0
    for f in "$REPO_ROOT"/lib/core/*.sh "$REPO_ROOT"/lib/distro/*.sh "$REPO_ROOT"/lib/handlers/*.sh "$REPO_ROOT"/lib/modules/*.sh "$REPO_ROOT"/scripts/*.sh; do
        if [[ -f "$f" ]]; then
            bash -n "$f" 2>/dev/null || { echo "Syntax error in: $f"; errors=$((errors + 1)); }
        fi
    done
    [ "$errors" -eq 0 ] || fail "$errors files with syntax errors"
}

@test "all handler files define audit and apply functions" {
    for f in "$REPO_ROOT"/lib/handlers/*.sh; do
        local basename
        basename=$(basename "$f" .sh)
        # Normalize handler name (replace - with _)
        local func_name="${basename//-/_}"

        # Source the file
        source "$REPO_ROOT/lib/core/log.sh"
        source "$REPO_ROOT/lib/core/utils.sh"
        LOG_LEVEL="ERROR"
        source "$f"

        declare -f "handler_${func_name}_audit" > /dev/null || fail "Missing handler_${func_name}_audit in $f"
        declare -f "handler_${func_name}_apply" > /dev/null || fail "Missing handler_${func_name}_apply in $f"
    done
}

@test "all module files define audit and apply functions" {
    source "$REPO_ROOT/lib/core/log.sh"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/core/config.sh"
    LOG_LEVEL="ERROR"

    for f in "$REPO_ROOT"/lib/modules/[0-9]*.sh; do
        source "$f"
        local num
        num=$(basename "$f" | cut -d- -f1)

        declare -f "audit_module_${num}" > /dev/null || fail "Missing audit_module_${num} in $f"
        declare -f "apply_module_${num}" > /dev/null || fail "Missing apply_module_${num} in $f"
    done
}

@test "module-dispatch.sh defines dispatch_audit and dispatch_apply" {
    source "$REPO_ROOT/lib/core/log.sh"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/core/config.sh"
    LOG_LEVEL="ERROR"
    source "$REPO_ROOT/lib/modules/module-dispatch.sh"

    declare -f dispatch_audit > /dev/null || fail "Missing dispatch_audit"
    declare -f dispatch_apply > /dev/null || fail "Missing dispatch_apply"
}

@test "dispatch_audit handles empty controls array" {
    source "$REPO_ROOT/lib/core/log.sh"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/core/config.sh"
    source "$REPO_ROOT/lib/modules/module-dispatch.sh"
    LOG_LEVEL="ERROR"

    # Create a JSON file with empty controls
    cat > "$TEST_DIR/empty.json" <<'EOF'
{"section":"99","title":"Empty","controls":[]}
EOF

    local output
    output=$(dispatch_audit "$TEST_DIR/empty.json")
    [ -z "$output" ]  # No output for empty controls
}

@test "handler type names in JSON match handler function names" {
    # Extract all type values from all module JSONs
    local types
    types=$(jq -r '.controls[].type' "$REPO_ROOT"/config/modules/*.json 2>/dev/null | sort -u)

    # Check each type has a corresponding handler file
    while IFS= read -r handler_type; do
        [ -z "$handler_type" ] && continue
        local file="$REPO_ROOT/lib/handlers/${handler_type}.sh"
        [ -f "$file" ] || fail "No handler file for type '$handler_type' (expected $file)"
    done <<< "$types"
}

@test "no duplicate control IDs within same distro scope" {
    for f in "$REPO_ROOT"/config/modules/*.json; do
        # Get controls without distro_only (shared)
        local shared_dupes
        shared_dupes=$(jq -r '[.controls[] | select(.distro_only == null)] | group_by(.id) | map(select(length > 1)) | .[].[] | .id' "$f" 2>/dev/null)
        [ -z "$shared_dupes" ] || fail "Duplicate shared IDs in $f: $shared_dupes"

        # Check each distro_only scope
        for distro in rhel9 ubuntu2404; do
            local distro_dupes
            distro_dupes=$(jq -r --arg d "$distro" '[.controls[] | select(.distro_only == $d)] | group_by(.id) | map(select(length > 1)) | .[].[] | .id' "$f" 2>/dev/null)
            [ -z "$distro_dupes" ] || fail "Duplicate $distro IDs in $f: $distro_dupes"
        done
    done
}

@test "scripts have executable permissions" {
    for f in "$REPO_ROOT"/scripts/*.sh; do
        [ -x "$f" ] || fail "$f is not executable"
    done
}

@test "cis-audit.sh --help works" {
    local output
    output=$("$REPO_ROOT/scripts/cis-audit.sh" --help 2>&1) || true
    echo "$output" | grep -q "force" || fail "Help output missing --force"
}
