# EBS Quick Reference

## Enable EBS Storage in 3 Steps

### Step 1: Update Configuration
```yaml
# deployment/group_vars/all.yml

enable_ebs_volume: true
ebs_volume_size: 100              # GB
ebs_volume_type: "gp3"            # gp3 (default), gp2, io1, st1
ebs_volume_mount_path: "/data"    # Where to mount
ebs_volume_encrypted: true        # Security
```

### Step 2: Deploy with EBS
```bash
# Launch EC2 with attached EBS volume
ansible-playbook playbooks/launch-ec2-instance.yml

# Setup application (includes mounting EBS)
ansible-playbook -i inventories playbooks/setup.yml
```

### Step 3: Verify
```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_IP

# Check mounted volumes
df -h
# Output: /data should appear

# Check device
lsblk | grep xvdf1
```

---

## Configuration Options

```yaml
enable_ebs_volume: false|true              # Enable/disable (default: false)

ebs_volume_size: 100                       # Size in GB (default: 100)
                                           # Min: 1, Max: 16,384

ebs_volume_type: "gp3"|"gp2"|"io1"|"st1"  # Type (default: gp3)
                                           # gp3: General purpose (fast, cheap)
                                           # gp2: Legacy general purpose
                                           # io1: High IOPS (expensive)
                                           # st1: Throughput optimized

ebs_volume_mount_path: "/data"             # Mount point (default: /data)

ebs_volume_encrypted: true|false           # Encrypt (default: true)

ebs_volume_snapshot_id: ""                 # Restore from snapshot
                                           # Example: snap-0123456789abcdef0
                                           # Empty = new volume
```

---

## Common Scenarios

### Small Application (100 GB)
```yaml
enable_ebs_volume: true
ebs_volume_size: 100
ebs_volume_type: "gp3"
ebs_volume_mount_path: "/data"
```

### Medium Workload (500 GB)
```yaml
enable_ebs_volume: true
ebs_volume_size: 500
ebs_volume_type: "gp3"
ebs_volume_mount_path: "/data"
```

### High Performance Database (1 TB)
```yaml
enable_ebs_volume: true
ebs_volume_size: 1000
ebs_volume_type: "io1"              # High IOPS
ebs_volume_mount_path: "/var/lib/postgresql"
```

### Archive Storage (2 TB)
```yaml
enable_ebs_volume: true
ebs_volume_size: 2000
ebs_volume_type: "st1"              # Throughput optimized
ebs_volume_mount_path: "/archive"
```

---

## Pricing Examples

| Size | Type | Monthly Cost |
|------|------|--------------|
| 100 GB | gp3 | $10 |
| 500 GB | gp3 | $50 |
| 1 TB | gp3 | $100 |
| 500 GB | io1 | ~$200+ |

---

## Troubleshooting

### Volume Not Found
```bash
# Run this on EC2 instance:
lsblk
# Should show: xvdf (100G)

# If not found:
# 1. Verify enable_ebs_volume: true
# 2. Wait 30 seconds after launch
# 3. Re-run setup.yml
```

### Mount Point Issues
```bash
# Check mount status:
df -h | grep /data

# Manual mount:
sudo mkdir -p /data
sudo mount /dev/xvdf1 /data
sudo chown ubuntu:ubuntu /data
```

### Permission Problems
```bash
# Fix ownership:
sudo chown ubuntu:ubuntu /data
sudo chmod 755 /data
```

---

## What's Included

When `enable_ebs_volume: true`:

✅ EBS volume created and attached  
✅ Automatic XFS filesystem creation  
✅ Automatic mounting at specified path  
✅ Added to /etc/fstab (survives reboot)  
✅ Permissions set for admin_user  
✅ Volume encrypted by default  

---

## Next Steps

1. **Detailed Guide:** See `EBS_STORAGE.md`
2. **AWS Docs:** https://docs.aws.amazon.com/ebs/
3. **Pricing:** https://aws.amazon.com/ebs/pricing/

---

## File Locations

After setup, volume is:
- **Device:** `/dev/xvdf1`
- **Mounted at:** `/data` (default) or custom path
- **Mount config:** `/etc/fstab`
- **Application data:** Store here using mount path


