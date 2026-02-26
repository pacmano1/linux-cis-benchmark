#!/usr/bin/env bash
# lib/core/report.sh — JSON + HTML report generation

# Generate summary statistics from NDJSON results
# Input: NDJSON on stdin
# Output: JSON summary object
generate_summary() {
    jq -s '{
        total: length,
        pass: [.[] | select(.status == "Pass")] | length,
        fail: [.[] | select(.status == "Fail")] | length,
        skip: [.[] | select(.status == "Skip")] | length,
        timestamp: (now | todate),
        pass_pct: (if length > 0 then
            (([.[] | select(.status == "Pass")] | length) * 100 / ([.[] | select(.status != "Skip")] | length))
        else 0 end)
    }'
}

# Generate JSON report from NDJSON results
# Usage: generate_json_report results.ndjson output.json
generate_json_report() {
    local input_file="$1"
    local output_file="$2"

    local hostname distro_label kernel_ver
    hostname="$(hostname -f 2>/dev/null || hostname)"
    distro_label="${DISTRO_LABEL:-Unknown}"
    kernel_ver="$(uname -r)"

    jq -s --arg host "$hostname" --arg distro "$distro_label" --arg kernel "$kernel_ver" '{
        report: {
            title: "CIS Linux Benchmark L1 Audit Report",
            hostname: $host,
            distro: $distro,
            kernel: $kernel,
            timestamp: (now | todate),
            dry_run: (env.DRY_RUN // "true")
        },
        summary: {
            total: length,
            pass: [.[] | select(.status == "Pass")] | length,
            fail: [.[] | select(.status == "Fail")] | length,
            skip: [.[] | select(.status == "Skip")] | length
        },
        results: .
    }' "$input_file" > "$output_file"

    log_info "JSON report written to: $output_file"
}

# Generate HTML report from NDJSON results
# Usage: generate_html_report results.ndjson output.html
generate_html_report() {
    local input_file="$1"
    local output_file="$2"

    local hostname distro_label kernel_ver timestamp
    hostname="$(hostname -f 2>/dev/null || hostname)"
    distro_label="${DISTRO_LABEL:-Unknown}"
    kernel_ver="$(uname -r)"
    timestamp="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    local total pass fail skip
    total=$(wc -l < "$input_file" | tr -d ' ')
    pass=$(grep -c '"Pass"' "$input_file" || true)
    fail=$(grep -c '"Fail"' "$input_file" || true)
    skip=$(grep -c '"Skip"' "$input_file" || true)
    local audited=$((total - skip))
    local pass_pct=0
    if (( audited > 0 )); then
        pass_pct=$(( pass * 100 / audited ))
    fi

    cat > "$output_file" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>CIS Linux Benchmark L1 Audit — ${hostname}</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 2em; background: #f8f9fa; }
  h1 { color: #1a1a2e; }
  .summary { display: flex; gap: 1em; margin: 1em 0; }
  .card { padding: 1em 1.5em; border-radius: 8px; color: #fff; min-width: 120px; }
  .card-pass { background: #28a745; }
  .card-fail { background: #dc3545; }
  .card-skip { background: #ffc107; color: #333; }
  .card-total { background: #6c757d; }
  .card h2 { margin: 0; font-size: 2em; }
  .card p { margin: 0.3em 0 0; }
  table { border-collapse: collapse; width: 100%; margin-top: 1em; background: #fff; }
  th, td { padding: 0.6em 1em; text-align: left; border-bottom: 1px solid #dee2e6; }
  th { background: #1a1a2e; color: #fff; }
  .status-Pass { color: #28a745; font-weight: bold; }
  .status-Fail { color: #dc3545; font-weight: bold; }
  .status-Skip { color: #ffc107; font-weight: bold; }
  tr:hover { background: #f1f3f5; }
  .meta { color: #6c757d; font-size: 0.9em; margin-bottom: 1em; }
</style>
</head>
<body>
<h1>CIS Linux Benchmark L1 Audit Report</h1>
<div class="meta">
  <strong>Host:</strong> ${hostname} &nbsp;|&nbsp;
  <strong>Distro:</strong> ${distro_label} &nbsp;|&nbsp;
  <strong>Kernel:</strong> ${kernel_ver} &nbsp;|&nbsp;
  <strong>Date:</strong> ${timestamp}
</div>
<div class="summary">
  <div class="card card-pass"><h2>${pass}</h2><p>Pass</p></div>
  <div class="card card-fail"><h2>${fail}</h2><p>Fail</p></div>
  <div class="card card-skip"><h2>${skip}</h2><p>Skip</p></div>
  <div class="card card-total"><h2>${total}</h2><p>Total (${pass_pct}% of audited)</p></div>
</div>
<table>
<thead><tr><th>ID</th><th>Title</th><th>Status</th><th>Expected</th><th>Actual</th><th>Detail</th></tr></thead>
<tbody>
HTMLEOF

    while IFS= read -r line; do
        local id title status expected actual detail
        id=$(echo "$line" | jq -r '.id')
        title=$(echo "$line" | jq -r '.title')
        status=$(echo "$line" | jq -r '.status')
        expected=$(echo "$line" | jq -r '.expected // ""')
        actual=$(echo "$line" | jq -r '.actual // ""')
        detail=$(echo "$line" | jq -r '.detail // ""')
        cat >> "$output_file" <<ROW
<tr><td>${id}</td><td>${title}</td><td class="status-${status}">${status}</td><td>${expected}</td><td>${actual}</td><td>${detail}</td></tr>
ROW
    done < "$input_file"

    cat >> "$output_file" <<'HTMLEOF'
</tbody>
</table>
</body>
</html>
HTMLEOF

    log_info "HTML report written to: $output_file"
}

# Print console summary
print_summary() {
    local input_file="$1"

    local total pass fail skip
    total=$(wc -l < "$input_file" | tr -d ' ')
    pass=$(grep -c '"Pass"' "$input_file" || true)
    fail=$(grep -c '"Fail"' "$input_file" || true)
    skip=$(grep -c '"Skip"' "$input_file" || true)
    local audited=$((total - skip))
    local pass_pct=0
    if (( audited > 0 )); then
        pass_pct=$(( pass * 100 / audited ))
    fi

    printf '\n'
    printf '  %s━━━ CIS L1 Audit Summary ━━━%s\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %sPass:%s  %d\n' "$COLOR_GREEN" "$COLOR_RESET" "$pass"
    printf '  %sFail:%s  %d\n' "$COLOR_RED" "$COLOR_RESET" "$fail"
    printf '  %sSkip:%s  %d\n' "$COLOR_YELLOW" "$COLOR_RESET" "$skip"
    printf '  Total: %d  (%d%% of audited)\n' "$total" "$pass_pct"
    printf '\n'
}
