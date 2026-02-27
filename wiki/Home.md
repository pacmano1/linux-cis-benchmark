# CIS Benchmark L1 Automation — Linux

Automated audit, enforcement, and rollback of CIS Level 1 Server benchmarks for **RHEL 9** and **Ubuntu 24.04 LTS**. Multi-distro, AWS EC2 aware, DryRun by default.

---

## What This Does

| Capability | Description |
|---|---|
| **Audit** | Scans a Linux server against 264 CIS L1 controls and generates HTML + JSON compliance reports |
| **Apply** | Applies CIS hardening (sysctl, modprobe, sshd, PAM, auditd, services, firewall, file permissions) |
| **Rollback** | Restores to pre-apply state from timestamped backup |

## Key Safety Features

- **Interactive prompts** — scripts ask for options (mode, modules, GDM, firewall) instead of requiring CLI flags
- **DryRun by default** — nothing changes until you explicitly opt in with `--dry-run false`
- **Auto-detects distro** — RHEL 9 vs Ubuntu 24.04 from `/etc/os-release`
- **AWS-aware** — auto-detects EC2 instances, skips bootloader/wireless/GDM controls
- **GDM-aware** — prompts to skip desktop controls on headless servers (`--skip-gdm`)
- **Full state backup** before every live apply operation
- **NDJSON result stream** — machine-parseable output for CI/CD integration

## Quick Start

```bash
# 1. Install prerequisites (jq, aide, audit)
sudo ./scripts/install-prerequisites.sh

# 2. Audit current compliance (safe — read-only)
sudo ./scripts/cis-audit.sh

# 3. Review the HTML report in reports/

# 4. Apply settings (prompts for mode, modules, GDM, firewall)
sudo ./scripts/cis-apply.sh

# 5. If something goes wrong
sudo ./scripts/cis-rollback.sh
```

> **Tip:** All scripts accept `--force` to skip prompts and `--skip-gdm` to exclude GDM desktop controls on headless servers.

## Wiki Pages

| Page | Description |
|---|---|
| [Architecture](Architecture.md) | Project structure, handler dispatch, distro abstraction |
| [Configuration](Configuration.md) | Master config, distro configs, AWS exclusions |
| [Modules](Modules.md) | Detailed breakdown of all 7 CIS sections and their controls |
| [Audit Guide](Usage-Audit.md) | Running audits, reading reports, filtering by module |
| [Apply Guide](Usage-Apply.md) | Dry run, live apply, handler mechanisms |
| [Rollback Guide](Usage-Rollback.md) | Restoring from backup |
| [AWS Considerations](AWS-Considerations.md) | EC2 exclusions, SSM Agent, IMDS |
| [Adding Controls](Adding-Controls.md) | How to add new controls or support new distros |
| [Troubleshooting](Troubleshooting.md) | Common issues and solutions |

## Requirements

- RHEL 9 (or AlmaLinux/Rocky 9) or Ubuntu 24.04 LTS
- Bash 4.2+
- `jq` (installed via `install-prerequisites.sh`)
- Root/sudo access
- Optional: `aide`, `audit`/`auditd` packages

## Control Coverage

| # | Section | Controls |
|---|---------|----------|
| 1 | Initial Setup | 70 |
| 2 | Services | 33 |
| 3 | Network Configuration | 30 |
| 4 | Firewall Configuration | 15 |
| 5 | Access, Authentication and Authorization | 49 |
| 6 | Logging and Auditing | 42 |
| 7 | System Maintenance | 25 |
| | **Total** | **264** |
