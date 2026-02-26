#!/usr/bin/env bats
# tests/report.bats — Test report generation

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$REPO_ROOT/lib/core/log.sh"
    source "$REPO_ROOT/lib/core/utils.sh"
    source "$REPO_ROOT/lib/core/report.sh"
    LOG_LEVEL="ERROR"

    # Create temp directory for test outputs
    BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    TEST_DIR=$(mktemp -d "$BATS_TMPDIR/cis-test-XXXXXX")

    # Create sample NDJSON results file
    cat > "$TEST_DIR/results.ndjson" <<'EOF'
{"id":"1.1.1","title":"Test Pass","status":"Pass","expected":"0","actual":"0","detail":"ok"}
{"id":"1.1.2","title":"Test Fail","status":"Fail","expected":"1","actual":"0","detail":"mismatch"}
{"id":"1.1.3","title":"Test Skip","status":"Skip","expected":"","actual":"","detail":"excluded"}
{"id":"1.1.4","title":"Another Pass","status":"Pass","expected":"yes","actual":"yes","detail":"ok"}
EOF
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "generate_summary produces correct counts" {
    local summary
    summary=$(cat "$TEST_DIR/results.ndjson" | generate_summary)

    local total
    total=$(echo "$summary" | jq '.total')
    [ "$total" -eq 4 ]

    local pass
    pass=$(echo "$summary" | jq '.pass')
    [ "$pass" -eq 2 ]

    local fail
    fail=$(echo "$summary" | jq '.fail')
    [ "$fail" -eq 1 ]

    local skip
    skip=$(echo "$summary" | jq '.skip')
    [ "$skip" -eq 1 ]
}

@test "generate_json_report creates valid JSON file" {
    DISTRO_LABEL="Test Linux"
    generate_json_report "$TEST_DIR/results.ndjson" "$TEST_DIR/report.json"

    [ -f "$TEST_DIR/report.json" ]
    jq '.' "$TEST_DIR/report.json" > /dev/null || fail "Invalid JSON report"

    local total
    total=$(jq '.summary.total' "$TEST_DIR/report.json")
    [ "$total" -eq 4 ]
}

@test "generate_json_report includes metadata" {
    DISTRO_LABEL="Test Linux"
    generate_json_report "$TEST_DIR/results.ndjson" "$TEST_DIR/report.json"

    local title
    title=$(jq -r '.report.title' "$TEST_DIR/report.json")
    [ "$title" = "CIS Linux Benchmark L1 Audit Report" ]

    local distro
    distro=$(jq -r '.report.distro' "$TEST_DIR/report.json")
    [ "$distro" = "Test Linux" ]
}

@test "generate_html_report creates HTML file" {
    DISTRO_LABEL="Test Linux"
    generate_html_report "$TEST_DIR/results.ndjson" "$TEST_DIR/report.html"

    [ -f "$TEST_DIR/report.html" ]
    grep -q "<!DOCTYPE html>" "$TEST_DIR/report.html" || fail "Not valid HTML"
    grep -q "CIS Linux Benchmark" "$TEST_DIR/report.html" || fail "Missing title in HTML"
}

@test "generate_html_report contains all result rows" {
    DISTRO_LABEL="Test Linux"
    generate_html_report "$TEST_DIR/results.ndjson" "$TEST_DIR/report.html"

    grep -q "1.1.1" "$TEST_DIR/report.html" || fail "Missing control 1.1.1"
    grep -q "1.1.4" "$TEST_DIR/report.html" || fail "Missing control 1.1.4"
    grep -q "Test Pass" "$TEST_DIR/report.html" || fail "Missing title"
    grep -q "status-Fail" "$TEST_DIR/report.html" || fail "Missing Fail status class"
}

@test "print_summary outputs to stdout" {
    local output
    output=$(print_summary "$TEST_DIR/results.ndjson")

    echo "$output" | grep -q "Pass" || fail "Missing Pass in summary"
    echo "$output" | grep -q "Fail" || fail "Missing Fail in summary"
}

@test "empty results file produces valid report" {
    : > "$TEST_DIR/empty.ndjson"
    DISTRO_LABEL="Test"
    generate_json_report "$TEST_DIR/empty.ndjson" "$TEST_DIR/empty-report.json"

    [ -f "$TEST_DIR/empty-report.json" ]
    local total
    total=$(jq '.summary.total' "$TEST_DIR/empty-report.json")
    [ "$total" -eq 0 ]
}
