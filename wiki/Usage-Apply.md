# Apply Guide

## Running an Apply

```bash
sudo ./scripts/cis-apply.sh
```

The script will:
1. Detect distro and load config
2. Prompt: "Run mode?" (default: dry run)
3. Prompt: "Is this a GDM desktop system?" (default: no)
4. Prompt: "Module selection?" (default: all)
5. Prompt: "Enable firewall rule hardening?" (default: no)
6. If live mode: prompt "Type YES to confirm"
7. If live mode: create backup
8. Run apply for all selected controls
9. If live mode: run post-apply audit

## Dry Run vs Live

### Dry Run (default)

- Reports what **would** change without modifying anything
- Safe to run in production
- Results show `[DRY RUN] Would set...` in the detail field

### Live Mode

- Creates a timestamped backup in `backups/` first
- Applies changes (sysctl, modprobe, sshd_config, PAM, services, etc.)
- Runs a post-apply audit to verify changes took effect
- Some changes require a reboot (e.g., kernel module blacklisting, GRUB changes)

## CLI Options

| Flag | Description |
|------|-------------|
| `--force` | Skip all interactive prompts |
| `--dry-run false` | Enable live mode without prompting |
| `--skip-gdm` | Skip GDM desktop controls |
| `--modules 1,3,5` | Apply specific modules only |
| `--harden-firewall` | Enable firewall hardening without prompting |
| `--log-level DEBUG` | Verbose logging |

## Examples

```bash
# Dry run, all modules (default)
sudo ./scripts/cis-apply.sh

# Live apply, network + services only
sudo ./scripts/cis-apply.sh --dry-run false --modules 2,3

# Fully automated live apply (CI/CD)
sudo ./scripts/cis-apply.sh --force --dry-run false --skip-gdm

# Dry run with verbose output
sudo ./scripts/cis-apply.sh --log-level DEBUG
```

## What Each Handler Applies

| Handler | Audit Mechanism | Apply Mechanism |
|---------|----------------|-----------------|
| `sysctl` | `sysctl -n key` | `sysctl -w` + persist to `/etc/sysctl.d/99-cis-benchmark.conf` |
| `kernel-module` | Check `/etc/modprobe.d/`, `lsmod` | Write to `/etc/modprobe.d/cis-*.conf`, `modprobe -r` |
| `service` | `systemctl is-enabled` | `systemctl stop/disable/mask` |
| `package` | `rpm -q` / `dpkg-query` | `dnf install/remove` / `apt install/purge` |
| `file-content` | `grep` directive in config file | `sed` or append to config file |
| `file-perms` | `stat -c '%a %U %G'` | `chmod`, `chown`, `chgrp` |
| `mount-option` | `findmnt -o OPTIONS` | Modify `/etc/fstab`, `mount -o remount` |
| `auditd-rule` | `auditctl -l` + `/etc/audit/rules.d/` | Append to rules file, `augenrules --load` |
| `pam` | Check `faillock.conf` / `pwquality.conf` | `sed` or append to config |
| `mac` | `getenforce` / `aa-status` | `setenforce` / `aa-enforce`, update config |
| `firewall` | `firewall-cmd` / `ufw status` | `firewall-cmd --set-default-zone` / `ufw enable` |
| `command` | Run `audit_cmd` | Run `apply_cmd` |

## Post-Apply

After a live apply:
- Review the post-apply audit summary
- Some changes require a **reboot**: kernel module blacklisting, GRUB audit parameters, SELinux mode changes
- Test connectivity (SSH, applications) before logging out
