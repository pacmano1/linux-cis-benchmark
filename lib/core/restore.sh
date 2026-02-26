#!/usr/bin/env bash
# lib/core/restore.sh — Restore from backup

# Restore system state from a backup directory
restore_from_backup() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi

    if [[ ! -f "${backup_dir}/metadata.json" ]]; then
        log_error "No metadata.json in backup — invalid backup directory"
        return 1
    fi

    log_info "Restoring from backup: $backup_dir"

    # Restore sysctl settings
    if [[ -f "${backup_dir}/sysctl.conf" ]]; then
        log_info "Restoring sysctl settings..."
        while IFS='=' read -r key value; do
            key="$(echo "$key" | xargs)"
            value="$(echo "$value" | xargs)"
            if [[ -n "$key" && -n "$value" && "$key" != "#"* ]]; then
                sysctl -w "${key}=${value}" &>/dev/null || true
            fi
        done < "${backup_dir}/sysctl.conf"
    fi

    # Restore /etc/modprobe.d/
    if [[ -d "${backup_dir}/modprobe.d" ]]; then
        log_info "Restoring /etc/modprobe.d/..."
        cp -a "${backup_dir}/modprobe.d"/* /etc/modprobe.d/ 2>/dev/null || true
    fi

    # Restore sshd_config
    if [[ -f "${backup_dir}/sshd_config" ]]; then
        log_info "Restoring sshd_config..."
        cp -a "${backup_dir}/sshd_config" /etc/ssh/sshd_config
    fi
    if [[ -d "${backup_dir}/sshd_config.d" ]]; then
        cp -a "${backup_dir}/sshd_config.d"/* /etc/ssh/sshd_config.d/ 2>/dev/null || true
    fi

    # Restore login.defs
    if [[ -f "${backup_dir}/login.defs" ]]; then
        log_info "Restoring login.defs..."
        cp -a "${backup_dir}/login.defs" /etc/login.defs
    fi

    # Restore PAM config
    if [[ -d "${backup_dir}/pam.d" ]]; then
        log_info "Restoring /etc/pam.d/..."
        cp -a "${backup_dir}/pam.d"/* /etc/pam.d/ 2>/dev/null || true
    fi

    # Restore /etc/security/
    if [[ -d "${backup_dir}/security" ]]; then
        log_info "Restoring /etc/security/..."
        cp -a "${backup_dir}/security"/* /etc/security/ 2>/dev/null || true
    fi

    # Restore fstab
    if [[ -f "${backup_dir}/fstab" ]]; then
        log_info "Restoring /etc/fstab..."
        cp -a "${backup_dir}/fstab" /etc/fstab
    fi

    # Restore audit rules
    if [[ -d "${backup_dir}/audit" ]]; then
        log_info "Restoring /etc/audit/..."
        cp -a "${backup_dir}/audit"/* /etc/audit/ 2>/dev/null || true
        if command_exists augenrules; then
            augenrules --load &>/dev/null || true
        fi
    fi

    # Restore rsyslog
    if [[ -f "${backup_dir}/rsyslog.conf" ]]; then
        cp -a "${backup_dir}/rsyslog.conf" /etc/rsyslog.conf 2>/dev/null || true
    fi
    if [[ -d "${backup_dir}/rsyslog.d" ]]; then
        cp -a "${backup_dir}/rsyslog.d"/* /etc/rsyslog.d/ 2>/dev/null || true
    fi

    # Restore journald
    if [[ -f "${backup_dir}/journald.conf" ]]; then
        cp -a "${backup_dir}/journald.conf" /etc/systemd/journald.conf 2>/dev/null || true
    fi

    # Restore banners
    for f in issue issue.net motd; do
        if [[ -f "${backup_dir}/${f}" ]]; then
            cp -a "${backup_dir}/${f}" "/etc/${f}" 2>/dev/null || true
        fi
    done

    log_info "Restore complete from: $backup_dir"
    log_warn "Some changes may require service restarts or a reboot to take effect"
}
