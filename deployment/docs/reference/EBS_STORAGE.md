# EBS Storage Configuration Guide

**Date:** February 21, 2026  
**Status:** ✅ Fully Supported

## Overview

Your deployment now supports optional **EBS (Elastic Block Store)** volume attachment to EC2 instances. This allows you to add persistent block storage beyond the root volume.

---

## What is EBS Storage?

**EBS** is AWS's block storage service for EC2 instances:
- Persists independently of instance lifecycle
- Can be detached and reattached
- Supports snapshots and backups
- Multiple performance tiers

**Use Cases:**
- Additional data storage (large files, databases)
- Higher performance requirements
- Backup and archival storage
- Expanding beyond root volume capacity

---

## Configuration

### Quick Start: Enable EBS Volume

In `deployment/group_vars/all.yml`:

```yaml
# ============================================================================
# EBS Volume Configuration
# ============================================================================

enable_ebs_volume: true                         # Set to true to attach EBS volume

ebs_volume_size: 100                            # Volume size in GB (default: 100)
                                                # Minimum: 1 GB, Maximum: 16,384 GB
                                                # Cost: ~$0.10/GB/month for gp3

ebs_volume_type: "gp3"                          # Volume type (default: gp3)
                                                # gp3: General Purpose (fast, cost-effective)
                                                # gp2: General Purpose (older, 3 IOPS/GB)
                                                # io1: High IOPS (expensive)
                                                # st1: Throughput optimized (for big data)

ebs_volume_mount_path: "/data"                  # Where to mount (default: /data)

ebs_volume_encrypted: true                      # Encrypt volume (default: true)
                                                # Recommended for security

ebs_volume_snapshot_id: ""                      # Optional: Restore from snapshot
                                                # Leave empty for new volume
                                                # Example: snap-0123456789abcdef0
```

### Default Configuration (Disabled)

```yaml
enable_ebs_volume: false                        # EBS disabled (uses root volume only)
```

---

## Volume Types & Pricing

| Type | IOPS | Throughput | Use Case | Cost |
|------|------|-----------|----------|------|
| **gp3** | 3,000-16,000 | 125-1,000 MB/s | General purpose, default | $0.10/GB/month |
| **gp2** | 100-16,000 | 20-250 MB/s | Legacy, avoid | $0.10/GB/month |
| **io1** | 100-64,000 | 50-1,000 MB/s | Databases, high performance | $0.125/GB + $0.065/IOPS |
| **st1** | 40-500 | 40-500 MB/s | Big data, throughput | $0.045/GB/month |

**Recommendation:** Use `gp3` for most workloads (good balance of performance and cost)

---

## Cost Examples

| Size | Type | Monthly Cost |
|------|------|--------------|
| 100 GB | gp3 | ~$10/month |
| 500 GB | gp3 | ~$50/month |
| 1 TB | gp3 | ~$100/month |
| 1 TB | io1 (3,000 IOPS) | ~$265/month |

---

## How It Works

### Deployment Flow

1. **Instance Creation** (`launch-ec2-instance.yml`)
   - Creates EC2 instance with root volume (20 GB)
   - Attaches additional EBS volume (size = `ebs_volume_size`)
   - Device name: `/dev/sdf`

2. **Server Setup** (`setup.yml`)
   - Detects EBS volume on `/dev/sdf`
   - Creates XFS filesystem
   - Mounts to `ebs_volume_mount_path` (default: `/data`)
   - Adds to `/etc/fstab` for auto-mounting on reboot

3. **Runtime**
   - Volume remains mounted across reboots
   - Application can store files at `/data` (or custom path)
   - Data persists if instance is stopped/started
   - Data lost only if volume is deleted

### Architecture

```
EC2 Instance
├── Root Volume (/dev/xvda)
│   ├── Size: 20 GB
│   ├── Type: gp3
│   └── Contains: OS, application code
│
└── Data Volume (/dev/sdf)
    ├── Size: configurable (default: 100 GB)
    ├── Type: configurable (default: gp3)
    ├── Mount: /data (or custom path)
    └── Contains: application data, backups
```

---

## Enabling EBS Volume

### Step 1: Update Configuration

```yaml
# deployment/group_vars/all.yml

enable_ebs_volume: true
ebs_volume_size: 100
ebs_volume_type: "gp3"
ebs_volume_mount_path: "/data"
ebs_volume_encrypted: true
```

### Step 2: Run Deployment

```bash
# Launch instance with EBS volume attached
ansible-playbook playbooks/launch-ec2-instance.yml

# This will:
# - Create EC2 instance
# - Attach 100 GB gp3 EBS volume as /dev/sdf
# - Tag instance with EBSVolume: Attached

# Setup application
ansible-playbook -i inventories playbooks/setup.yml

# This will:
# - Format EBS volume with XFS filesystem
# - Mount at /data
# - Add to /etc/fstab
# - Set permissions for admin_user
```

### Step 3: Verify

```bash
# SSH to instance
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_IP

# Check mounted volumes
df -h
# Should show:
# /data       100G      10G   91G  10% /data

# Check block devices
lsblk
# Should show:
# xvdf   259:96   0 100G  0 disk
# └─xvdf1 259:97   0 100G  0 part /data

# Check fstab
cat /etc/fstab | grep /data
# Should show:
# UUID=abcd-1234... /data xfs defaults,nofail 0 0
```

---

## Using EBS Volume for Application Data

### Store Application Data

```bash
# Your app can now write to /data
# Example: store user uploads, images, cache

# In your application code:
DATA_DIR = "/data"
BACKUP_DIR = "/data/backups"
CACHE_DIR = "/data/cache"

# Create directories
sudo mkdir -p /data/backups /data/cache
sudo chown {app_user}:{app_user} /data/backups /data/cache
```

### Example: Store S3 Backups Locally First

```bash
# Download from S3 to fast local storage
aws s3 sync s3://your-bucket/backups /data/backups --region us-east-2

# Process locally
process_backups /data/backups

# Upload processed files to S3
aws s3 sync /data/backups s3://your-bucket/processed --region us-east-2

# Clear local cache
rm -rf /data/backups/*
```

---

## Restoration from Snapshot

### Restore from Existing Snapshot

If you want to restore a volume from a previous snapshot:

```yaml
# deployment/group_vars/all.yml

enable_ebs_volume: true
ebs_volume_size: 100                            # Same size as snapshot
ebs_volume_type: "gp3"
ebs_volume_mount_path: "/data"
ebs_volume_snapshot_id: "snap-0123456789abcdef0"  # Your snapshot ID
ebs_volume_encrypted: true
```

Then run:
```bash
ansible-playbook playbooks/launch-ec2-instance.yml
ansible-playbook -i inventories playbooks/setup.yml
```

The playbook will:
1. Create EBS volume from snapshot
2. Skip formatting (volume already has filesystem)
3. Mount to `/data` automatically
4. Restore all data from snapshot

---

## Backup & Snapshots

### Create Snapshot from AWS Console

```
EC2 → Volumes → Select {app_name}-data
→ Actions → Create snapshot
```

### Create Snapshot from CLI

```bash
# Get volume ID
aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values={app_name}" \
  --region us-east-2 \
  --query 'Volumes[0].VolumeId'

# Create snapshot
aws ec2 create-snapshot \
  --volume-id vol-xxxxxxxxx \
  --description "Backup of {app_name} data" \
  --region us-east-2
```

### Automated Snapshots

Add to crontab on your local machine:

```bash
# Daily snapshot at 2 AM
0 2 * * * /path/to/snapshot-script.sh
```

Script example:
```bash
#!/bin/bash
VOLUME_ID=$(aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=myapp" \
  --region us-east-2 \
  --query 'Volumes[0].VolumeId' \
  --output text)

aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "Automated backup $(date +%Y-%m-%d)" \
  --region us-east-2
```

---

## Troubleshooting

### Volume Not Detected

**Problem:** EBS volume not found during setup

**Check:**
```bash
ssh ubuntu@YOUR_IP
lsblk
# Should show /dev/xvdf
```

**Solutions:**
1. Ensure `enable_ebs_volume: true` in all.yml
2. Wait 30 seconds after instance launch for volume to attach
3. Re-run `ansible-playbook setup.yml` to detect and mount

### Mount Point Not Created

**Problem:** /data directory exists but volume not mounted

**Check:**
```bash
df -h | grep /data
# Should show volume mounted

mount | grep /data
# Should show mount entry
```

**Fix:**
```bash
sudo mkdir -p /data
sudo mount /dev/xvdf1 /data
sudo chmod 755 /data
sudo chown ubuntu:ubuntu /data
```

### Permission Issues

**Problem:** Application cannot write to /data

**Check:**
```bash
ls -ld /data
# Should show: drwxr-xr-x ubuntu ubuntu

# If wrong, fix permissions:
sudo chown ubuntu:ubuntu /data
sudo chmod 755 /data
```

### Increase Volume Size

**Problem:** Need more storage

**Steps:**
1. Create snapshot of current volume
2. Create new larger volume from snapshot
3. Detach old volume
4. Attach new volume (same device name)
5. Extend filesystem:
   ```bash
   sudo xfs_growfs /data
   ```

---

## Cost Optimization

### Right-Size Your Volume

Don't over-provision:
- Start with 100 GB (gp3)
- Monitor usage: `df -h`
- Increase only if needed

### Use GP3 (Not GP2)

- GP3 is 20% cheaper than GP2
- Better performance
- No reason to use GP2 anymore

### Clean Up Old Snapshots

```bash
# List snapshots
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=description,Values=*{app_name}*" \
  --region us-east-2

# Delete old snapshot
aws ec2 delete-snapshot \
  --snapshot-id snap-xxxxxxxxx \
  --region us-east-2
```

---

## Limitations & Notes

### Current Limitations

- **Single volume only:** Playbook supports one EBS volume per instance
- **Device name fixed:** Always `/dev/sdf` (secondary device)
- **No RAID:** Single volume configuration only
- **Manual extension:** Increasing size requires manual steps

### Future Enhancements

These could be added if needed:
- Multiple EBS volumes per instance
- Automatic volume resizing
- RAID configuration
- EBS-optimized instances
- Throughput allocation for io1/io2

---

## Advanced Configurations

### Use EBS for Database Storage

```yaml
# If running PostgreSQL or MySQL from the application

ebs_volume_size: 500                    # Larger for database
ebs_volume_type: "gp3"                  # Good for databases
ebs_volume_mount_path: "/var/lib/postgresql"  # Database directory
ebs_volume_encrypted: true              # Always for databases
```

### High-Performance Configuration

```yaml
# For I/O intensive workloads

ebs_volume_size: 200
ebs_volume_type: "io1"                  # High IOPS
ebs_volume_mount_path: "/data"
ebs_volume_encrypted: true

# Note: io1 is expensive, use only if needed
```

### Archive/Throughput Configuration

```yaml
# For large batch processing

ebs_volume_size: 1000                   # 1 TB
ebs_volume_type: "st1"                  # Throughput optimized
ebs_volume_mount_path: "/archive"
ebs_volume_encrypted: true
```

---

## See Also

- [AWS EBS Documentation](https://docs.aws.amazon.com/ebs/)
- [EBS Pricing](https://aws.amazon.com/ebs/pricing/)
- [PREREQUISITES.md](../guides/PREREQUISITES.md) - Setup guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture

