# AWS Considerations

## EC2 Auto-Detection

The framework auto-detects EC2 instances via:
1. **IMDS** — `curl http://169.254.169.254/latest/meta-data/instance-id`
2. **DMI fallback** — `/sys/class/dmi/id/product_uuid` starts with "ec2"

Override with `AWS_MODE` in `master.conf`:
- `auto` (default) — auto-detect
- `true` — force EC2 mode
- `false` — disable EC2 mode

## Skipped Controls on EC2

These controls are in `config/aws-exclusions.json` and are automatically skipped (19 total):

| Control | Reason |
|---------|--------|
| 1.4.1, 1.4.2 | Bootloader password — no physical/console access on EC2 |
| 1.8.1–1.8.10 | GDM desktop — headless EC2 servers |
| 2.1.9 | NFS server — required for EFS mounts |
| 2.1.12 | rpcbind — required for EFS/NFS |
| 3.1.1 | Wireless interfaces — no hardware |
| 3.1.2 | Bluetooth — no hardware |
| 3.3.11a, 3.3.11b | IPv6 router advertisements — required for dual-stack/IPv6 networking |
| 5.2.4 | NOPASSWD sudo — ec2-user/ubuntu default sudo requires NOPASSWD for cloud-init and SSM |

## Modified Controls on EC2

| Control | Modification | Reason |
|---------|-------------|--------|
| 5.1.21 | PermitRootLogin: `no` → `prohibit-password` | Key-based root SSH is standard on EC2 (no password auth) |
| 5.4.4 | INACTIVE: `30` → `180` days | EC2 automation accounts may not have interactive logins for months |
| 6.3.2.5 | admin_space_left_action: `halt` → `suspend` | Halting an EC2 instance when audit logs fill up is a self-inflicted DOS |

## Audit-Only Controls on EC2

In addition to skips and modifications, 29 controls are marked **audit-only** — they are reported but never applied by `cis-apply.sh` unless `--apply-all` is explicitly passed. This prevents the apply script from bricking an EC2 instance by:

- Disabling services the server intentionally runs (Samba, HTTP, NFS, DNS, etc.)
- Enabling firewalld/ufw with a drop/deny policy and no allow rules (SSH lockout)
- Locking out accounts via PAM faillock on root
- Halting the system when audit logs fill up

See [Apply Guide — Audit-Only Controls](Usage-Apply.md#audit-only-controls) for the full list.

## SSM Agent Considerations

The framework checks for SSM Agent status via `systemctl is-active amazon-ssm-agent`. If SSM Agent is running, be cautious with:

- **Service controls** — Don't disable services that SSM Agent depends on
- **Firewall rules** — Ensure outbound HTTPS (443) to SSM endpoints remains open
- **SSH controls** — SSM Session Manager is an alternative to SSH

## IMDS Security

EC2 instances should use IMDSv2 (token-required). This is a separate hardening concern outside the CIS benchmark but recommended:

```bash
aws ec2 modify-instance-metadata-options \
  --instance-id i-1234567890abcdef0 \
  --http-tokens required \
  --http-endpoint enabled
```

## Golden AMI Workflow

For building hardened AMIs:

```bash
# 1. Launch a base AMI
# 2. Install prerequisites
sudo ./scripts/install-prerequisites.sh --force

# 3. Apply hardening (live, non-interactive)
sudo ./scripts/cis-apply.sh --force --dry-run false --skip-gdm

# 4. Verify
sudo ./scripts/cis-audit.sh --force --skip-gdm

# 5. Clean up and create AMI
sudo rm -rf /tmp/* /var/tmp/*
# Create AMI via AWS Console or CLI
```

## Adding Custom Exclusions

To skip additional controls for your environment, add entries to `config/aws-exclusions.json`:

```json
{
  "skip": [
    {"id": "2.1.9", "reason": "NFS required for EFS mounts"}
  ]
}
```

Or use runtime skip via `add_skip_ids` in a wrapper script.
