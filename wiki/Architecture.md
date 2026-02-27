# Architecture

## Design Principles

1. **Config-driven** — Controls are defined in JSON, not code. Adding a control means adding a JSON entry.
2. **Handler dispatch** — Controls declare a `type`; the framework calls the matching handler function automatically.
3. **Distro abstraction** — Distro-specific operations go through adapter functions, not `if/else` in handlers.
4. **NDJSON streaming** — Each result is one JSON line, composable with standard Unix tools.
5. **Safe by default** — DryRun mode, interactive prompts, backups before changes, audit-only controls for dangerous operations.

## Directory Layout

```
linux-cis-benchmark/
├── config/
│   ├── master.conf              # Global settings (sourced as shell vars)
│   ├── aws-exclusions.json      # Skip/modify rules for EC2
│   ├── distro/
│   │   ├── rhel9.conf           # RHEL 9 overrides
│   │   └── ubuntu2404.conf      # Ubuntu 24.04 overrides
│   └── modules/                 # One JSON per CIS section
│       ├── 1-initial-setup.json
│       ├── 2-services.json
│       ├── 3-network.json
│       ├── 4-firewall.json
│       ├── 5-access-control.json
│       ├── 6-logging.json
│       └── 7-maintenance.json
├── scripts/                     # Entry points (user-facing)
├── lib/
│   ├── core/                    # Framework infrastructure
│   │   ├── init.sh              # Bootstrap (sources everything)
│   │   ├── config.sh            # Load configs + exclusions
│   │   ├── log.sh               # Structured logging
│   │   ├── prompt.sh            # Interactive prompts
│   │   ├── report.sh            # JSON + HTML report generation
│   │   ├── backup.sh            # State snapshot
│   │   ├── restore.sh           # Restore from backup
│   │   ├── connectivity.sh      # AWS IMDS/SSM checks
│   │   └── utils.sh             # emit_result(), resolve_control(), helpers
│   ├── distro/                  # Distro abstraction
│   │   ├── detect.sh            # Auto-detect from /etc/os-release
│   │   ├── rhel9.sh             # RHEL 9 adapter
│   │   └── ubuntu2404.sh        # Ubuntu 24.04 adapter
│   ├── handlers/                # Mechanism-based audit/apply
│   │   ├── sysctl.sh
│   │   ├── kernel-module.sh
│   │   ├── service.sh
│   │   ├── package.sh
│   │   ├── file-content.sh
│   │   ├── file-perms.sh
│   │   ├── mount-option.sh
│   │   ├── auditd-rule.sh
│   │   ├── pam.sh
│   │   ├── mac.sh
│   │   ├── firewall.sh
│   │   └── command.sh
│   └── modules/                 # Per-section orchestrators
│       ├── module-dispatch.sh   # Generic dispatch logic
│       └── [1-7]-*.sh           # Section wrappers
└── tests/                       # BATS tests
```

## Data Flow

### Audit Flow

```
cis-audit.sh
  → init.sh (bootstrap)
  → load_all_config() (master.conf + distro + AWS exclusions)
  → prompts (GDM, modules)
  → for each module:
      → audit_module_N(config_file)
        → dispatch_audit(config_file)
          → for each control in JSON:
              → resolve_control() (skip? distro? modify?)
              → handler_${type}_audit(control_json)
              → emit_result() → NDJSON line to stdout
  → generate reports (JSON + HTML)
  → print summary
```

### Apply Flow

Same as audit but:
1. Prompts for mode (dry-run/live) and confirmation
2. Creates backup before live apply
3. For each control:
   - If `audit_only: true` (and `--apply-all` not set): runs the audit handler only (reports status, does not apply)
   - Otherwise: calls `handler_${type}_apply`
4. Runs post-apply audit in live mode

## Handler Dispatch

Controls in JSON declare their `type` field. The module orchestrator calls:

```bash
handler_${type}_audit "$control_json"    # audit mode
handler_${type}_apply "$control_json"    # apply mode
```

### Handler Types

| Type | What It Does | Example Controls |
|------|-------------|-----------------|
| `sysctl` | Kernel parameters | net.ipv4.ip_forward, kernel.randomize_va_space |
| `kernel-module` | /etc/modprobe.d/ blacklisting | cramfs, dccp, sctp |
| `service` | systemctl enable/disable/mask | autofs, cups, sshd |
| `package` | Package installed/removed | sudo, telnet, gdm |
| `file-content` | Config file directives | sshd_config, login.defs, journald.conf |
| `file-perms` | File permission/ownership | /etc/passwd, /etc/shadow |
| `mount-option` | fstab mount options | nodev, nosuid, noexec on /tmp |
| `auditd-rule` | Audit daemon rules | identity, time-change, scope |
| `pam` | PAM config (faillock, pwquality) | deny, unlock_time, minlen |
| `mac` | SELinux / AppArmor | enforcing, policy, profiles |
| `firewall` | firewalld / ufw | installed, active, default zone |
| `command` | Generic command checks | bootloader, banners, crypto policy |

## Distro Abstraction

Each adapter (`lib/distro/rhel9.sh`, `lib/distro/ubuntu2404.sh`) implements the same function interface:

| Function | Purpose |
|----------|---------|
| `distro_pkg_installed` | Check if a package is installed |
| `distro_pkg_install` | Install a package |
| `distro_pkg_remove` | Remove a package |
| `distro_mac_status` | Get MAC status (SELinux/AppArmor) |
| `distro_mac_enforcing` | Check if MAC is enforcing |
| `distro_mac_set_enforcing` | Set MAC to enforce mode |
| `distro_firewall_active` | Check if firewall is running |
| `distro_firewall_default_zone` | Get default zone/policy |
| `distro_firewall_list_rules` | List firewall rules |
| `distro_time_sync_service` | Get time sync service name |
| `distro_time_sync_active` | Check if time sync is running |

Handlers call these functions instead of distro-specific commands directly.

## Control JSON Format

```json
{
  "id": "3.3.1a",
  "title": "Ensure ip forwarding is disabled - net.ipv4.ip_forward",
  "type": "sysctl",
  "key": "net.ipv4.ip_forward",
  "expected": "0"
}
```

Optional fields:
- `distro_only` — Only run on this distro (`"rhel9"` or `"ubuntu2404"`)
- `distro` — Per-distro field overrides: `{"ubuntu2404": {"service": "cron"}}`
- `audit_only` — If `true`, apply mode runs the audit handler instead of apply (safety mechanism)

## NDJSON Result Format

Each audit/apply result is one JSON line:

```json
{"id":"3.3.1a","title":"...","status":"Pass","expected":"0","actual":"0","detail":"sysctl net.ipv4.ip_forward"}
```

Status values: `Pass`, `Fail`, `Skip`
