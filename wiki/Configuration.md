# Configuration

## Master Config (`config/master.conf`)

Shell-sourceable file with global settings:

```bash
DRY_RUN=true          # true = audit only, false = live apply
LOG_LEVEL="INFO"      # DEBUG, INFO, WARN, ERROR
LOG_FILE="reports/cis-benchmark.log"
REPORT_DIR="reports"
BACKUP_DIR="backups"
AWS_MODE="auto"       # auto, true, false

# Module enable/disable (1=enabled, 0=disabled)
MODULE_1_INITIAL_SETUP=1
MODULE_2_SERVICES=1
MODULE_3_NETWORK=1
MODULE_4_FIREWALL=1
MODULE_5_ACCESS_CONTROL=1
MODULE_6_LOGGING=1
MODULE_7_MAINTENANCE=1
```

## Distro Configs (`config/distro/`)

Sourced after `master.conf` when the distro is detected. Sets distro-specific variables:

### RHEL 9 (`rhel9.conf`)
```bash
DISTRO_ID="rhel9"
PKG_MANAGER="dnf"
MAC_SYSTEM="selinux"
FIREWALL_SYSTEM="firewalld"
PAM_TOOL="authselect"
TIME_SYNC_SERVICE="chronyd"
```

### Ubuntu 24.04 (`ubuntu2404.conf`)
```bash
DISTRO_ID="ubuntu2404"
PKG_MANAGER="apt"
MAC_SYSTEM="apparmor"
FIREWALL_SYSTEM="ufw"
PAM_TOOL="pam-auth-update"
TIME_SYNC_SERVICE="chrony"
```

## AWS Exclusions (`config/aws-exclusions.json`)

Controls skipped or modified when running on EC2. Auto-loaded when IMDS is reachable (or `AWS_MODE=true`).

### Skip Array

Controls that are not applicable on EC2 (19 controls):

```json
{
  "skip": [
    {"id": "1.4.1", "reason": "Bootloader password — no physical/console access on EC2"},
    {"id": "2.1.9", "reason": "NFS server — required for EFS mounts on EC2"},
    {"id": "2.1.12", "reason": "rpcbind — required for EFS/NFS on EC2"},
    {"id": "3.1.1", "reason": "Wireless interfaces — no hardware on EC2"},
    {"id": "3.3.11a", "reason": "IPv6 router advertisements — required for EC2 dual-stack"},
    {"id": "5.2.4", "reason": "NOPASSWD sudo — ec2-user/ubuntu default requires NOPASSWD"}
  ]
}
```

### Modify Object

Controls where the expected value differs on EC2 (3 controls):

```json
{
  "modify": {
    "5.1.21": {
      "field": "expected",
      "value": "prohibit-password",
      "reason": "SSH root login with key-based auth OK on EC2"
    },
    "5.4.4": {
      "field": "expected",
      "value": "INACTIVE=180",
      "reason": "Extended to 180 days — automation accounts may not log in for months"
    },
    "6.3.2.5": {
      "field": "expected",
      "value": "suspend",
      "reason": "suspend instead of halt — halting on full audit logs is a self-inflicted DOS"
    }
  }
}
```

## Module Configs (`config/modules/`)

One JSON file per CIS section. Each contains a `controls` array:

```json
{
  "section": "3",
  "title": "Network Configuration",
  "controls": [
    {
      "id": "3.3.1a",
      "title": "Ensure ip forwarding is disabled",
      "type": "sysctl",
      "key": "net.ipv4.ip_forward",
      "expected": "0"
    }
  ]
}
```

### Control Fields

**Required** (all controls):
- `id` — CIS control ID
- `title` — Human-readable description
- `type` — Handler type (determines which handler processes this control)

**Optional** (all controls):
- `distro_only` — Only run on this distro (`"rhel9"` or `"ubuntu2404"`)
- `distro` — Per-distro field overrides
- `audit_only` — If `true`, this control is audited but never applied unless `--apply-all` is passed. Used for dangerous controls (services, firewall, account lockout). See [Apply Guide](Usage-Apply.md#audit-only-controls).

**Type-specific fields** — See [Architecture](Architecture.md) for handler field details.

## Exclusion Mechanism

The exclusion system works at three levels:

### 1. Static (aws-exclusions.json)
Loaded at startup when EC2 is detected. Controls marked as skipped produce `Skip` status in results.

### 2. Runtime (--skip-gdm flag)
GDM desktop control IDs (1.8.1–1.8.10) are added to the skip list dynamically when the user answers "no" to the GDM prompt or passes `--skip-gdm`.

### 3. Audit-only (audit_only field)
Controls with `"audit_only": true` are **always audited** (in both audit and apply modes) but are **never applied** unless `--apply-all` is passed. This is a safety mechanism for controls that could break a running system — services, firewalls, account lockouts. See [Apply Guide](Usage-Apply.md#audit-only-controls).

Levels 1 and 2 use `resolve_control()` in `lib/core/utils.sh` to check the skip list. Level 3 is enforced in `dispatch_apply()` in `lib/modules/module-dispatch.sh`.
