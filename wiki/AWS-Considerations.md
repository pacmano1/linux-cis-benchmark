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

These controls are in `config/aws-exclusions.json` and are automatically skipped:

| Control | Reason |
|---------|--------|
| 1.4.1, 1.4.2 | Bootloader password — no physical/console access on EC2 |
| 3.1.1 | Wireless interfaces — no hardware |
| 3.1.2 | Bluetooth — no hardware |
| 1.8.1–1.8.10 | GDM desktop — headless EC2 servers |

## Modified Controls on EC2

| Control | Modification | Reason |
|---------|-------------|--------|
| 5.1.21 | PermitRootLogin changed from `no` to `prohibit-password` | Key-based root SSH is standard on EC2 (no password auth) |

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
