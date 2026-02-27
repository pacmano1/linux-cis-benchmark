# Modules

## Overview

| # | Section | Controls | Config File |
|---|---------|----------|-------------|
| 1 | Initial Setup | 70 | `1-initial-setup.json` |
| 2 | Services | 33 | `2-services.json` |
| 3 | Network Configuration | 30 | `3-network.json` |
| 4 | Firewall Configuration | 15 | `4-firewall.json` |
| 5 | Access, Authentication and Authorization | 49 | `5-access-control.json` |
| 6 | Logging and Auditing | 42 | `6-logging.json` |
| 7 | System Maintenance | 25 | `7-maintenance.json` |
| | **Total** | **264** | |

---

## 1. Initial Setup (70 controls)

### 1.1 Filesystem Configuration (34 controls)
- **1.1.1.x** — Disable unused filesystem kernel modules (cramfs, freevxfs, hfs, hfsplus, jffs2, squashfs, udf, usb-storage)
- **1.1.2.x–1.1.8.x** — Mount point hardening (/tmp, /var, /var/tmp, /var/log, /var/log/audit, /home, /dev/shm) with nodev, nosuid, noexec

### 1.2 Package Management (3 controls)
- GPG key validation, repo_gpgcheck (RHEL only)

### 1.3 Mandatory Access Control (10 controls)
- **RHEL 9**: SELinux installed, not disabled in bootloader, targeted policy, enforcing mode, no unconfined services
- **Ubuntu 24.04**: AppArmor installed, enabled in bootloader, enforce mode, profiles loaded

### 1.4 Bootloader (2 controls)
- Bootloader password set, config permissions (600 root:root)

### 1.5 Additional Process Hardening (4 controls)
- ASLR enabled, ptrace_scope restricted, core dumps disabled

### 1.6 Crypto Policy (2 controls, RHEL only)
- System crypto policy not LEGACY, SHA1/CBC disabled for SSH

### 1.7 Warning Banners (6 controls)
- motd, /etc/issue, /etc/issue.net content and permissions

### 1.8 GDM Desktop (10 controls)
- Skipped on headless servers via `--skip-gdm`
- GDM removed/configured, XDMCP disabled

---

## 2. Services (33 controls)

### 2.1 Server Services (21 controls) — audit-only
Ensure unnecessary server services are disabled: autofs, avahi, dhcp, dns, dnsmasq, ftp, ldap, mail (IMAP), NFS, NIS, CUPS, rpcbind, rsync, samba, snmp, telnet, tftp, squid, httpd/apache, xinetd, MTA local-only.

**All 21 controls are audit-only** — they are reported but never applied by `cis-apply.sh` unless `--apply-all` is passed. Servers exist to run services; blindly disabling them breaks things.

Distro overrides for service names (e.g., `dhcpd` vs `isc-dhcp-server`, `httpd` vs `apache2`).

### 2.2 Client Services (6 controls)
Ensure unnecessary client packages are not installed: ypbind, rsh, talk, telnet, ldap-utils, ftp.

### 2.3 Time Synchronization (4 controls)
- chrony/systemd-timesyncd active, chrony configured with NTP servers, not running as root

### 2.4 Cron (2 controls)
- Cron enabled, /etc/crontab permissions (600 root:root)

---

## 3. Network Configuration (30 controls)

### 3.1 Unused Protocols (3 controls)
- IPv6 status, wireless disabled, bluetooth disabled

### 3.2 Kernel Modules (4 controls)
- Disable dccp, tipc, rds, sctp

### 3.3 Network Parameters (23 controls)
sysctl hardening: IP forwarding, ICMP redirects, source routing, SYN cookies, reverse path filtering, martian logging, router advertisements. Each parameter checked for both `conf.all` and `conf.default` (and IPv4/IPv6 where applicable).

---

## 4. Firewall Configuration (15 controls)

### 4.1 RHEL 9 — firewalld (7 controls)
- firewalld installed, iptables-services removed, nftables removed, service enabled, default zone set to `drop`, interfaces assigned, unnecessary services dropped
- **4.1.4 (enable) and 4.1.5 (drop zone) are audit-only** — enabling firewalld with a `drop` zone and no allow rules drops all traffic including SSH

### 4.2 Ubuntu 24.04 — ufw (7 controls)
- ufw installed, iptables-persistent removed, service enabled, rules exist, default deny policy, loopback configured, outbound configured
- **4.2.3 (enable) and 4.2.5 (default deny) are audit-only** — enabling ufw with default deny and no SSH rule = instant lockout

### 4.3 nftables (1 control)
- Base filter chains exist

---

## 5. Access, Authentication and Authorization (49 controls)

### 5.1 SSH Server (23 controls)
- sshd_config permissions, host key permissions
- Ciphers, KEX, MACs (no weak algorithms)
- Banner, ClientAliveInterval, MaxAuthTries, MaxSessions, MaxStartups
- PermitRootLogin, PermitEmptyPasswords, HostbasedAuth, IgnoreRhosts, UsePAM
- DisableForwarding, GSSAPIAuthentication, PermitUserEnvironment, LogLevel

### 5.2 sudo (7 controls)
- sudo installed, use_pty, logfile, no NOPASSWD, no !authenticate, timeout, su restricted

### 5.3 PAM (10 controls)
- faillock: deny=5, unlock_time=900, even_deny_root
- pwquality: minlen=14, dcredit/ucredit/lcredit/ocredit=-1, remember=24
- Password hashing SHA-512 or yescrypt

### 5.4 User Accounts (9 controls)
- PASS_MAX_DAYS, PASS_MIN_DAYS, PASS_WARN_AGE, INACTIVE lock
- Root GID 0, umask 027, TMOUT, securetty, root access logged

---

## 6. Logging and Auditing (42 controls)

### 6.1 AIDE (2 controls)
- AIDE installed, filesystem integrity regularly checked

### 6.2.1 journald (4 controls)
- Service active, compress, persistent storage, ForwardToSyslog

### 6.2.2 rsyslog (7 controls)
- Installed, enabled, file permissions 0640, logging configured, remote log host, not receiving remote

### 6.3.1 auditd Config (5 controls)
- Installed (audit/auditd), enabled, audit=1 in GRUB, backlog_limit

### 6.3.2 Data Retention (5 controls)
- max_log_file, keep_logs, space_left_action, action_mail_acct, admin_space_left_action

### 6.3.3 Audit Rules (17 controls)
- scope, user_emulation, sudo_log, time-change, system-locale, privileged commands, file access, identity, perm_mod, mounts, session, logins, delete, MAC-policy, chcon, kernel_modules, immutable (-e 2)

### 6.4 Log File Permissions (2 controls)
- /var/log/ file permissions, all logfile permissions

---

## 7. System Maintenance (25 controls)

### 7.1 File Permissions (14 controls)
- /etc/passwd, /etc/shadow, /etc/group, /etc/gshadow (and backup files)
- No world-writable files, no unowned/ungrouped files, sticky bit on world-writable dirs
- SUID/SGID executables reviewed

### 7.2 User/Group Validation (11 controls)
- Shadowed passwords, no empty password fields
- All GIDs exist in /etc/group, no duplicate UIDs/GIDs/usernames/groupnames
- Root PATH integrity, root is only UID 0
- Home directories exist, dot file permissions

---

## Distro-Specific Controls

Controls use `distro_only` to restrict to a single distro. The framework skips controls that don't match the detected distro.

| Area | RHEL 9 | Ubuntu 24.04 |
|------|--------|--------------|
| MAC | SELinux (6 controls) | AppArmor (4 controls) |
| Crypto policy | update-crypto-policies (2 controls) | N/A |
| Firewall | firewalld (7 controls) | ufw (7 controls) |
| Package mgr | dnf/rpm | apt/dpkg |
| auditd package | `audit` | `auditd` |
| Cron service | `crond` | `cron` |
| Time sync | `chronyd` | `chrony` or `systemd-timesyncd` |
