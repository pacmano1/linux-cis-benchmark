#!/usr/bin/env bash
# lib/core/backup.sh — State snapshot before apply

# Create a timestamped backup directory and snapshot system state
# Returns the backup directory path via stdout
create_backup() {
    local backup_root="${REPO_ROOT}/${BACKUP_DIR:-backups}"
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    local backup_dir="${backup_root}/${timestamp}"

    mkdir -p "$backup_dir"
    log_info "Creating backup in: $backup_dir"

    # Backup sysctl settings
    if command_exists sysctl; then
        sysctl -a > "${backup_dir}/sysctl.conf" 2>/dev/null || true
        log_debug "Backed up sysctl settings"
    fi

    # Backup /etc/modprobe.d/
    if [[ -d /etc/modprobe.d ]]; then
        cp -a /etc/modprobe.d "${backup_dir}/modprobe.d" 2>/dev/null || true
        log_debug "Backed up /etc/modprobe.d/"
    fi

    # Backup sshd_config
    if [[ -f /etc/ssh/sshd_config ]]; then
        cp -a /etc/ssh/sshd_config "${backup_dir}/sshd_config" 2>/dev/null || true
        log_debug "Backed up sshd_config"
    fi
    if [[ -d /etc/ssh/sshd_config.d ]]; then
        cp -a /etc/ssh/sshd_config.d "${backup_dir}/sshd_config.d" 2>/dev/null || true
    fi

    # Backup /etc/login.defs
    if [[ -f /etc/login.defs ]]; then
        cp -a /etc/login.defs "${backup_dir}/login.defs" 2>/dev/null || true
    fi

    # Backup PAM configuration
    if [[ -d /etc/pam.d ]]; then
        cp -a /etc/pam.d "${backup_dir}/pam.d" 2>/dev/null || true
        log_debug "Backed up /etc/pam.d/"
    fi

    # Backup /etc/security/
    if [[ -d /etc/security ]]; then
        cp -a /etc/security "${backup_dir}/security" 2>/dev/null || true
    fi

    # Backup fstab
    if [[ -f /etc/fstab ]]; then
        cp -a /etc/fstab "${backup_dir}/fstab" 2>/dev/null || true
    fi

    # Backup audit rules
    if [[ -d /etc/audit ]]; then
        cp -a /etc/audit "${backup_dir}/audit" 2>/dev/null || true
        log_debug "Backed up /etc/audit/"
    fi

    # Backup firewall state
    if command_exists firewall-cmd; then
        firewall-cmd --list-all > "${backup_dir}/firewalld.txt" 2>/dev/null || true
    elif command_exists ufw; then
        ufw status verbose > "${backup_dir}/ufw.txt" 2>/dev/null || true
    fi

    # Backup systemd service states
    systemctl list-unit-files --type=service --no-pager > "${backup_dir}/services.txt" 2>/dev/null || true

    # Backup rsyslog config
    if [[ -f /etc/rsyslog.conf ]]; then
        cp -a /etc/rsyslog.conf "${backup_dir}/rsyslog.conf" 2>/dev/null || true
    fi
    if [[ -d /etc/rsyslog.d ]]; then
        cp -a /etc/rsyslog.d "${backup_dir}/rsyslog.d" 2>/dev/null || true
    fi

    # Backup journald config
    if [[ -f /etc/systemd/journald.conf ]]; then
        cp -a /etc/systemd/journald.conf "${backup_dir}/journald.conf" 2>/dev/null || true
    fi

    # Backup /etc/issue and /etc/issue.net
    for f in /etc/issue /etc/issue.net /etc/motd; do
        if [[ -f "$f" ]]; then
            cp -a "$f" "${backup_dir}/$(basename "$f")" 2>/dev/null || true
        fi
    done

    # Record metadata
    cat > "${backup_dir}/metadata.json" <<EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "hostname": "$(hostname -f 2>/dev/null || hostname)",
  "distro": "${DISTRO_LABEL:-unknown}",
  "kernel": "$(uname -r)",
  "modules": "$(echo "${SELECTED_MODULES[@]:-all}")"
}
EOF

    log_info "Backup complete: $backup_dir"
    echo "$backup_dir"
}

# List available backups
list_backups() {
    local backup_root="${REPO_ROOT}/${BACKUP_DIR:-backups}"
    if [[ ! -d "$backup_root" ]]; then
        echo "No backups found."
        return 1
    fi

    local count=0
    for dir in "$backup_root"/*/; do
        if [[ -f "${dir}metadata.json" ]]; then
            count=$((count + 1))
            local ts
            ts="$(jq -r '.timestamp' "${dir}metadata.json")"
            local distro
            distro="$(jq -r '.distro' "${dir}metadata.json")"
            printf '  %d. %s (%s) — %s\n' "$count" "$(basename "$dir")" "$distro" "$ts"
        fi
    done

    if (( count == 0 )); then
        echo "No backups found."
        return 1
    fi
}
