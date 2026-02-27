# Rollback Guide

## Running a Rollback

```bash
sudo ./scripts/cis-rollback.sh
```

The script will:
1. List available backups (timestamped, with distro and date)
2. Prompt for backup selection (numbered list)
3. Prompt for module scope (all or selective)
4. Prompt: "Type YES to confirm"
5. Restore files from the selected backup

## CLI Options

| Flag | Description |
|------|-------------|
| `--force` | Skip prompts, use most recent backup |
| `--backup DIR` | Specify backup directory directly |
| `--modules 1,3,5` | Rollback specific modules only |

## Examples

```bash
# Interactive rollback
sudo ./scripts/cis-rollback.sh

# Automated: restore from most recent backup
sudo ./scripts/cis-rollback.sh --force

# Restore from specific backup
sudo ./scripts/cis-rollback.sh --backup backups/20260226_103000
```

## What Gets Restored

| Item | Backup Location | Restores To |
|------|----------------|-------------|
| sysctl settings | `sysctl.conf` | Re-applied via `sysctl -w` |
| modprobe configs | `modprobe.d/` | `/etc/modprobe.d/` |
| sshd_config | `sshd_config` | `/etc/ssh/sshd_config` |
| sshd_config.d/ | `sshd_config.d/` | `/etc/ssh/sshd_config.d/` |
| login.defs | `login.defs` | `/etc/login.defs` |
| PAM config | `pam.d/` | `/etc/pam.d/` |
| /etc/security/ | `security/` | `/etc/security/` |
| fstab | `fstab` | `/etc/fstab` |
| Audit rules | `audit/` | `/etc/audit/` |
| Firewall state | `firewalld.txt` or `ufw.txt` | Logged only (manual restore) |
| rsyslog | `rsyslog.conf`, `rsyslog.d/` | `/etc/rsyslog.conf`, `/etc/rsyslog.d/` |
| journald | `journald.conf` | `/etc/systemd/journald.conf` |
| Banners | `issue`, `issue.net`, `motd` | `/etc/issue`, etc. |

## Backup Structure

Each backup is a timestamped directory under `backups/`:

```
backups/20260226_103000/
├── metadata.json       # Timestamp, hostname, distro, kernel, modules
├── sysctl.conf
├── modprobe.d/
├── sshd_config
├── login.defs
├── pam.d/
├── security/
├── fstab
├── audit/
├── services.txt
├── rsyslog.conf
├── journald.conf
├── issue
├── issue.net
└── motd
```

## After Rollback

- Some changes require a **reboot** (kernel module loading, mount options)
- Restart affected services: `systemctl restart sshd auditd rsyslog`
- Run an audit to verify the rollback: `sudo ./scripts/cis-audit.sh --force`
