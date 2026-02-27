# Adding Controls

## Adding a New Control

### 1. Choose the handler type

Pick from the 12 existing handlers:

| Type | Use When |
|------|----------|
| `sysctl` | Kernel parameter (key/value) |
| `kernel-module` | Blacklist a kernel module |
| `service` | Enable/disable a systemd service |
| `package` | Install/remove a package |
| `file-content` | Check/set a directive in a config file |
| `file-perms` | Check/set file permissions/ownership |
| `mount-option` | Check/set fstab mount options |
| `auditd-rule` | Check/add an auditd rule |
| `pam` | Check/set PAM config (faillock, pwquality) |
| `mac` | Check/set SELinux or AppArmor |
| `firewall` | Check/set firewall rules |
| `command` | Generic command-based check |

### 2. Add the control to the JSON config

Edit the appropriate file in `config/modules/`. Add an entry to the `controls` array:

```json
{
  "id": "3.3.12",
  "title": "Ensure TCP timestamps are disabled",
  "type": "sysctl",
  "key": "net.ipv4.tcp_timestamps",
  "expected": "0"
}
```

That's it. The framework will automatically dispatch to `handler_sysctl_audit` and `handler_sysctl_apply`.

### 3. Audit-only controls

For controls that could break a running system (disabling services, enabling firewalls, locking accounts), add `"audit_only": true`. These controls will be reported during apply but never actually applied unless `--apply-all` is passed:

```json
{
  "id": "2.1.14",
  "title": "Ensure samba file server services are not in use",
  "type": "service",
  "service": "smb",
  "expected": "disabled",
  "audit_only": true
}
```

See [Apply Guide — Audit-Only Controls](Usage-Apply.md#audit-only-controls) for the full list.

### 4. Distro-specific controls

For controls that only apply to one distro:

```json
{
  "id": "1.6.3",
  "title": "Ensure crypto policy is FUTURE",
  "type": "command",
  "audit_cmd": "update-crypto-policies --show",
  "expected": "FUTURE",
  "match": "exact",
  "distro_only": "rhel9"
}
```

For controls that apply to both distros but with different parameters:

```json
{
  "id": "2.4.1",
  "title": "Ensure cron daemon is enabled",
  "type": "service",
  "service": "crond",
  "expected": "enabled",
  "distro": {
    "ubuntu2404": { "service": "cron" }
  }
}
```

## Adding a New Handler

If none of the 12 existing handlers fit:

### 1. Create the handler file

```bash
# lib/handlers/my-handler.sh
handler_my_handler_audit() {
    local control_json="$1"
    local id title
    id="$(ctl_field "$control_json" "id")"
    title="$(ctl_field "$control_json" "title")"

    # Your audit logic here
    local actual="..."
    local expected="..."

    if [[ "$actual" == "$expected" ]]; then
        emit_result "$id" "$title" "Pass" "$expected" "$actual" "detail"
    else
        emit_result "$id" "$title" "Fail" "$expected" "$actual" "detail"
    fi
}

handler_my_handler_apply() {
    local control_json="$1"
    # Check current state first
    local audit_result
    audit_result="$(handler_my_handler_audit "$control_json")"
    local status
    status="$(echo "$audit_result" | jq -r '.status')"

    if [[ "$status" == "Pass" ]]; then
        echo "$audit_result"
        return
    fi

    if [[ "${DRY_RUN:-true}" == "true" ]]; then
        echo "$audit_result" | jq -c '.detail = "[DRY RUN] Would apply..."'
        return
    fi

    # Your apply logic here
    emit_result "$id" "$title" "Pass" "$expected" "$expected" "Applied"
}
```

### 2. Use it in controls

```json
{
  "id": "X.Y.Z",
  "title": "My new control",
  "type": "my-handler",
  "custom_field": "value"
}
```

The file is auto-sourced by `init.sh` and the type is auto-dispatched.

## Adding a New Distro

### 1. Create the adapter

Copy an existing adapter and implement all `distro_*` functions:

```bash
cp lib/distro/rhel9.sh lib/distro/rhel8.sh
# Edit: change DISTRO_ID, DISTRO_LABEL, and any function differences
```

### 2. Create the config

```bash
cp config/distro/rhel9.conf config/distro/rhel8.conf
# Edit: change DISTRO_ID, DISTRO_LABEL
```

### 3. Add detection

Edit `lib/distro/detect.sh` to recognize the new distro in the `case` statement.

### 4. Add distro-specific controls

Add controls with `distro_only: "rhel8"` to the JSON configs, or add `distro` overrides.

## Testing New Controls

```bash
# Validate JSON
jq '.' config/modules/3-network.json

# Count controls
jq '.controls | length' config/modules/3-network.json

# Run single module audit
sudo ./scripts/cis-audit.sh --modules 3

# Verbose for debugging
sudo ./scripts/cis-audit.sh --modules 3 --log-level DEBUG
```
