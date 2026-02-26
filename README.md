# Linux CIS Benchmark L1 Automation

Bash-based automation for CIS Level 1 Server benchmarks on Linux. Supports RHEL 9 and Ubuntu 24.04 LTS with AWS EC2 awareness.

## Quick Start

```bash
# Install prerequisites (jq, aide, audit)
sudo ./scripts/install-prerequisites.sh

# Run audit (read-only, safe)
sudo ./scripts/cis-audit.sh

# Apply in dry-run mode (default — logs changes without applying)
sudo ./scripts/cis-apply.sh

# Apply live
sudo ./scripts/cis-apply.sh --dry-run false
```

## Features

- **264 controls** across 7 CIS sections
- **Multi-distro**: RHEL 9 and Ubuntu 24.04 LTS (auto-detected)
- **AWS-aware**: Auto-detects EC2 instances and applies appropriate exclusions
- **DryRun by default**: Audit-only mode, safe to run in production
- **NDJSON result stream**: Machine-parseable output, JSON + HTML reports
- **Backup/Rollback**: Full state snapshot before live apply
- **Modular**: Enable/disable sections independently

## Control Counts by Module

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

## CLI Options

### cis-audit.sh
| Flag | Description |
|------|-------------|
| `--force` | Skip all interactive prompts |
| `--skip-gdm` | Skip GDM desktop controls |
| `--modules 1,3,5` | Run specific modules only |
| `--log-level DEBUG` | Set log verbosity |

### cis-apply.sh
| Flag | Description |
|------|-------------|
| `--force` | Skip all interactive prompts |
| `--dry-run false` | Enable live mode |
| `--skip-gdm` | Skip GDM desktop controls |
| `--modules 1,3,5` | Apply specific modules only |
| `--harden-firewall` | Enable firewall hardening |

### cis-rollback.sh
| Flag | Description |
|------|-------------|
| `--force` | Skip prompts, use most recent backup |
| `--backup DIR` | Specify backup directory |

## Architecture

```
config/                    # JSON control definitions + settings
  master.conf              # Global settings (DRY_RUN, module toggles)
  aws-exclusions.json      # Skip/modify rules for EC2
  distro/                  # RHEL 9 / Ubuntu 24.04 overrides
  modules/                 # One JSON per CIS section (264 controls)
scripts/                   # Entry points
lib/
  core/                    # Config, logging, prompts, reports, backup
  distro/                  # Auto-detection + distro adapters
  handlers/                # Mechanism-based audit/apply (12 types)
  modules/                 # Per-section orchestrators
tests/                     # BATS tests
```

### Handler Types

Controls are dispatched by `type` field to mechanism-specific handlers:

| Handler | Mechanisms |
|---------|-----------|
| `sysctl` | Kernel parameters via sysctl |
| `kernel-module` | /etc/modprobe.d/ blacklisting |
| `service` | systemctl enable/disable/mask |
| `package` | Package installed/removed (dnf/apt) |
| `file-content` | Config file directives (sshd_config, login.defs, etc.) |
| `file-perms` | File permission and ownership |
| `mount-option` | fstab mount options |
| `auditd-rule` | Audit daemon rules |
| `pam` | PAM config (faillock, pwquality) |
| `mac` | SELinux / AppArmor |
| `firewall` | firewalld / ufw |
| `command` | Generic command-based checks |

## Testing

```bash
# Requires bats-core: https://github.com/bats-core/bats-core
bats tests/
```

## CIS Benchmark Attribution

This project implements recommendations from the following CIS Benchmarks, published by the [Center for Internet Security](https://www.cisecurity.org/):

- **CIS Red Hat Enterprise Linux 9 Benchmark v2.0.0** (Level 1 — Server)
- **CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0** (Level 1 — Server)

CIS Benchmarks are available free of charge at [https://www.cisecurity.org/cis-benchmarks](https://www.cisecurity.org/cis-benchmarks). Users of this tool should obtain their own copy of the applicable benchmarks to understand the full context, rationale, and remediation guidance for each control.

This project is not certified, endorsed, or affiliated with the Center for Internet Security. CIS and CIS Benchmarks are trademarks of the Center for Internet Security, Inc.

The automation code in this repository is licensed under the [MIT License](LICENSE). The CIS Benchmark content (control numbering, titles, and recommended values) is subject to the CIS Terms of Use.

## License

MIT — see [LICENSE](LICENSE).
