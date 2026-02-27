# Troubleshooting

## Common Issues

### "jq: command not found"

Install prerequisites first:

```bash
sudo ./scripts/install-prerequisites.sh
```

Or install jq manually:
```bash
# RHEL 9
sudo dnf install -y jq

# Ubuntu 24.04
sudo apt-get install -y jq
```

### "This script must be run as root"

All CIS audit and apply scripts require root access:

```bash
sudo ./scripts/cis-audit.sh
```

### "Cannot detect distro"

The framework reads `/etc/os-release`. If your distro isn't recognized, you'll see a warning. Currently supported:
- RHEL 9 (and AlmaLinux 9, Rocky Linux 9, Oracle Linux 9)
- Ubuntu 24.04 LTS

### "No audit function for module N"

The module orchestrator file is missing or not sourced. Check that `lib/modules/N-*.sh` exists and defines `audit_module_N()`.

### "No handler for type: xyz"

A control in JSON has a `type` value with no matching handler file. Check:
1. `lib/handlers/xyz.sh` exists
2. It defines `handler_xyz_audit()` and `handler_xyz_apply()`
3. The type name uses hyphens in JSON but underscores in function names (e.g., `file-content` → `handler_file_content_audit`)

### Controls showing "Skip" unexpectedly

Check for:
1. **AWS exclusions** — Is the control in `config/aws-exclusions.json` skip list?
2. **Distro mismatch** — Does the control have `distro_only` set to the other distro?
3. **GDM skip** — Did you answer "no" to the GDM prompt? Controls 1.8.1–1.8.10 are skipped.

```bash
# Check which controls are skipped and why
jq -r 'select(.status == "Skip") | "\(.id): \(.detail)"' reports/results_*.ndjson
```

### Apply changes not taking effect

Some changes require additional steps:
- **Kernel modules**: Reboot required for blacklisting to take full effect
- **GRUB changes** (audit=1, SELinux): Run `grub2-mkconfig` and reboot
- **sshd_config**: Restart SSH: `systemctl restart sshd`
- **PAM changes**: Take effect on next login
- **Mount options**: Remount or reboot: `mount -o remount /tmp`
- **auditd rules**: Restart auditd: `service auditd restart` (note: `systemctl` won't work for auditd on some distros)

### Dry run shows "Fail" for everything

This is expected. In dry-run mode, the apply script reports what **would** change. The detail field shows `[DRY RUN] Would set...`. No changes are made.

### HTML report won't open

Check that the report was generated:

```bash
ls -la reports/cis-audit_*.html
```

If on a headless server, copy to your local machine:

```bash
scp server:~/linux-cis-benchmark/reports/cis-audit_*.html .
```

## Debug Mode

Run with `--log-level DEBUG` for verbose output:

```bash
sudo ./scripts/cis-audit.sh --log-level DEBUG 2>debug.log
```

Debug output goes to stderr, results to stdout.

## Validating Config

```bash
# Validate all JSON configs
for f in config/modules/*.json config/aws-exclusions.json; do
    echo -n "$f: "
    jq '.' "$f" > /dev/null 2>&1 && echo "OK" || echo "INVALID"
done

# Check bash syntax of all scripts
for f in lib/**/*.sh scripts/*.sh; do
    bash -n "$f" || echo "SYNTAX ERROR: $f"
done

# Count controls per module
for f in config/modules/*.json; do
    printf "%-45s %d\n" "$(jq -r '.title' "$f")" "$(jq '.controls | length' "$f")"
done
```

## Running Tests

```bash
# Install bats-core
# RHEL: dnf install -y bats
# Ubuntu: apt-get install -y bats

bats tests/
```
