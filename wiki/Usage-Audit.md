# Audit Guide

## Running an Audit

```bash
sudo ./scripts/cis-audit.sh
```

The script will:
1. Detect your distro (RHEL 9 or Ubuntu 24.04)
2. Load AWS exclusions if running on EC2
3. Prompt: "Is this a GDM desktop system?" (default: no)
4. Prompt: "Module selection?" (default: all)
5. Run all enabled controls
6. Generate JSON + HTML reports in `reports/`
7. Print a summary to the console

## CLI Options

| Flag | Description |
|------|-------------|
| `--force` | Skip all interactive prompts (uses defaults) |
| `--skip-gdm` | Skip GDM desktop controls without prompting |
| `--modules 1,3,5` | Run specific modules only |
| `--log-level DEBUG` | Set log verbosity (DEBUG, INFO, WARN, ERROR) |

## Examples

```bash
# Full audit, no prompts
sudo ./scripts/cis-audit.sh --force

# Audit only network and firewall sections
sudo ./scripts/cis-audit.sh --modules 3,4

# Verbose audit for troubleshooting
sudo ./scripts/cis-audit.sh --log-level DEBUG

# Headless server, skip GDM
sudo ./scripts/cis-audit.sh --skip-gdm
```

## Reading Reports

### Console Summary

```
  ━━━ CIS L1 Audit Summary ━━━
  Pass:  198
  Fail:  42
  Skip:  24
  Total: 264  (82% of audited)
```

### HTML Report

Located in `reports/cis-audit_YYYYMMDD_HHMMSS.html`. Opens in any browser. Color-coded Pass/Fail/Skip with sortable table.

### JSON Report

Located in `reports/cis-audit_YYYYMMDD_HHMMSS.json`. Structure:

```json
{
  "report": {
    "title": "CIS Linux Benchmark L1 Audit Report",
    "hostname": "ip-10-0-1-50.ec2.internal",
    "distro": "RHEL 9",
    "kernel": "5.14.0-362.el9.x86_64",
    "timestamp": "2026-02-26T10:30:00Z"
  },
  "summary": { "total": 264, "pass": 198, "fail": 42, "skip": 24 },
  "results": [ ... ]
}
```

### NDJSON Results

Raw results file at `reports/results_YYYYMMDD_HHMMSS.ndjson`. One JSON line per control — useful for piping:

```bash
# Show only failures
jq -r 'select(.status == "Fail") | "\(.id) \(.title)"' reports/results_*.ndjson

# Count by status
jq -r '.status' reports/results_*.ndjson | sort | uniq -c

# Export failures to CSV
jq -r 'select(.status == "Fail") | [.id, .title, .expected, .actual] | @csv' reports/results_*.ndjson
```

## Scheduling Audits

```bash
# Daily audit via cron (headless, all modules, no prompts)
echo "0 2 * * * root /opt/linux-cis-benchmark/scripts/cis-audit.sh --force --skip-gdm" > /etc/cron.d/cis-audit
```
