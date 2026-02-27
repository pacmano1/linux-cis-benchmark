# CLAUDE.md

## Project Overview
CIS Benchmark L1 automation for Linux (RHEL 9 + Ubuntu 24.04 LTS). Bash-based, modular architecture with 264 controls across 7 modules. Supports multi-distro with auto-detection, AWS EC2 awareness. Safe by default: DryRun mode + 29 dangerous controls are audit-only.

## Repository Structure
```
config/                    # Settings + control definitions
  master.conf              # Global settings (DRY_RUN, module toggles, log level)
  aws-exclusions.json      # Skip array + Modify object (mirrors Windows pattern)
  distro/                  # Per-distro overrides (rhel9.conf, ubuntu2404.conf)
  modules/                 # One JSON per CIS section (1-7)
scripts/                   # Entry points (user-facing)
  cis-audit.sh             # Read-only audit
  cis-apply.sh             # Apply changes (DryRun default)
  cis-rollback.sh          # Restore from backup
  install-prerequisites.sh # Install jq, aide, audit packages
lib/
  core/                    # Infrastructure: init, config, log, prompt, report, backup, restore, connectivity, utils
  distro/                  # Auto-detection (detect.sh) + adapters (rhel9.sh, ubuntu2404.sh)
  handlers/                # Mechanism-based audit/apply (12 handler types)
  modules/                 # Per-section orchestrators (dispatch to handlers)
tests/                     # BATS tests
wiki/                      # Documentation
```

## Key Conventions

### Config Format
- Shell-sourceable `.conf` for settings (master.conf, distro overrides)
- **JSON** for control definitions — parsed with `jq`, safe, no code execution
- Loaded via `jq` (mirrors PowerShell's `Import-PowerShellDataFile`)

### Handler Dispatch
Controls in JSON have a `type` field. Module orchestrators dispatch via:
```bash
handler_${type}_audit "$control_json"    # audit mode
handler_${type}_apply "$control_json"    # apply mode
```
12 handler types: sysctl, kernel-module, service, package, file-content, file-perms, mount-option, auditd-rule, pam, mac, firewall, command

### Distro Abstraction
- Auto-detected from `/etc/os-release` in `lib/distro/detect.sh`
- Adapters provide standard `distro_*` functions (distro_pkg_installed, distro_mac_status, etc.)
- Controls use `distro_only` field for distro-specific controls
- Controls use `distro` override object for field overrides per distro

### Interactive Prompts
- All entry-point scripts prompt interactively by default
- `--force` skips ALL prompts
- CLI params skip their corresponding prompt when passed explicitly
- Prompt format: `  ? Question text? [D/l]:` (uppercase = default)
- `--skip-gdm` skips GDM controls without prompting

### Exclusion Mechanism
- `aws-exclusions.json` → `skip` array (19 controls) + `modify` object (3 controls)
- `lib/core/config.sh` loads exclusions into `_SKIP_IDS` / `_MODIFY_JSON`
- `resolve_control()` in utils.sh checks skip/distro/mods before dispatch
- GDM exclusions are dynamic/opt-in via `--skip-gdm` flag
- AWS skips: bootloader password, GDM, wireless/bluetooth, NFS/rpcbind (EFS), IPv6 RA, NOPASSWD sudo
- AWS mods: PermitRootLogin→prohibit-password, INACTIVE→180d, audit halt→suspend

### Audit-Only Controls
29 controls have `"audit_only": true` in JSON — audited but never applied unless `--apply-all` is passed:
- **2.1.1–2.1.21** (all server services): servers exist to run services
- **4.1.4, 4.1.5** (firewalld enable + drop zone): drops all traffic including SSH
- **4.2.3, 4.2.5** (ufw enable + default deny): blocks all inbound including SSH
- **5.1.4** (sshd AllowUsers/DenyUsers): misconfigured = SSH lockout
- **5.3.3** (PAM faillock even_deny_root): locks root after 5 bad passwords
- **5.4.4** (INACTIVE=30): locks automation accounts after 30 days
- **6.3.2.5** (auditd admin_space_left_action=halt): system halts when audit logs fill

Logic lives in `dispatch_apply()` in `lib/modules/module-dispatch.sh` — checks `audit_only` field, runs audit handler instead of apply handler. `APPLY_ALL=true` (from `--apply-all` flag) overrides.

### Apply Modes
- **DryRun** (default): logs what would change, no modifications
- **Live** (`--dry-run false`): creates backup first, then applies
- Post-apply audit only runs in live mode
- Audit-only controls are always reported (run audit handler) but never applied without `--apply-all`

### NDJSON Result Stream
Each audit/apply result is one JSON line:
```json
{"id":"3.3.1a","title":"...","status":"Pass","expected":"0","actual":"0","detail":"sysctl net.ipv4.ip_forward"}
```

## Testing
```bash
bats tests/
```

## CIS Attribution
Implements CIS RHEL 9 v2.0.0 and CIS Ubuntu 24.04 LTS v1.0.0 (L1 Server profile). Not affiliated with or endorsed by CIS. Users should obtain their own copy of the benchmarks from cisecurity.org.
