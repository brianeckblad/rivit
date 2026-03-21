# EBS Storage Reference

How the application uses EBS volumes for persistent storage.

## Overview

The application now runs **entirely on an EBS volume**, not on the EC2 root volume. This provides:

- ✅ Persistent application storage
- ✅ Easy backup via EBS snapshots
- ✅ Better performance (dedicated storage)
- ✅ Clean separation of OS and application
- ✅ Scalable storage independent of instance

---

## Architecture

### Volume Configuration

```
EC2 Instance
├── Root Volume (/dev/xvda)
│   ├── Size: 8 GB (fixed)
│   ├── Type: gp3 (encrypted)
│   ├── Purpose: OS only (Ubuntu 22.04)
│   ├── Contains: /home (SSH keys stay here)
│   └── Delete on termination: Yes
│
└── Application Volume (/dev/sdf) ← MANDATORY
    ├── Size: Configurable (default: 100 GB)
    ├── Type: Configurable (default: gp3)
    ├── Encryption: Enabled (AES-256)
    ├── Mount Point: /opt/{app_name}
    ├── Format: XFS
    │
    └── /opt/{app_name} (mounted at app_storage_mount_path)
        ├── Application Code
        ├── .venv/ (Python environment)
        ├── logs/ (Application logs)
        ├── instance/ (Runtime data)
        └── ... (all app files)
```

### Directory Structure

After deployment:

```
/opt/{app_name}                      # EBS volume mount point
├── .env                             # Application configuration
├── .venv/                           # Python virtual environment
│   ├── bin/
│   │   ├── python
│   │   ├── pip
│   │   ├── gunicorn
│   │   └── ...
│   ├── lib/
│   │   └── python3.x/
│   │       └── site-packages/
│   └── ...
├── logs/                            # Application logs
│   ├── app.log
│   ├── error.log
│   └── ...
├── instance/                        # Runtime data & cache
│   ├── data.csv
│   ├── cache/
│   └── ...
├── (application code files)
├── requirements.txt
├── app/
├── templates/
├── static/
└── ... (all application files)
```

### Storage Hierarchy

```
Configuration Variable: app_storage_mount_path
        ↓
    Default: /opt/{app_name} (e.g., /opt/myapp)
        ↓
    Used in:
    - app_dir: /opt/{app_name}
    - venv_dir: /opt/{app_name}/.venv
    - log_dir: /opt/{app_name}/logs
    - instance_dir: /opt/{app_name}/instance
```

---

## Configuration

### Minimal Setup

All you need to set in `vault.yml`:

```yaml
# APPLICATION IDENTITY
app_name: myapp                                  # Creates /opt/{app_name} mount point

# STORAGE CONFIGURATION (MANDATORY)
ebs_volume_size: 100                             # Size in GB
ebs_volume_type: "gp3"                           # Volume type
ebs_volume_encrypted: true                       # Encryption
```

That's it! Everything else is automatically configured.

### Optional Configuration

```yaml
# Override default mount path (not recommended)
app_storage_mount_path: "/my-custom-path"       # Default: /opt/{app_name}

# Use snapshot to restore data
ebs_volume_snapshot_id: "snap-0123456789abcdef0"

# Enable EBS optimization for high I/O
ec2_ebs_optimized: true
```

---

## How It Works

### 1. Instance Creation

```bash
cd deployment
ansible-playbook playbooks/launch-ec2-instance.yml \
    --vault-password-file ~/.vault_pass
```

**Creates:**
- EC2 instance with 20 GB root volume (OS)
- EBS data volume attached (configured size)
- Both volumes encrypted

### 2. Server Setup

```bash
cd deployment
ansible-playbook -i inventories playbooks/setup.yml \
    --vault-password-file ~/.vault_pass
```

**Steps in order:**
1. Install system dependencies
2. Create application user
3. **Mount EBS volume to /opt/{app_name}**
4. Clone application code
5. Create Python virtual environment
6. Install dependencies
7. Configure application
8. Start services

### 3. Application Location

After deployment, all application files are at:

```
/opt/{app_name}/                    # Everything here is on EBS volume
├── Code
├── Environment
├── Logs
└── Data
```

---

## File Locations

| Purpose | Location | Volume | Owner |
|---------|----------|--------|-------|
| Application code | `/opt/{app_name}` | EBS | ubuntu |
| Python venv | `/opt/{app_name}/.venv` | EBS | ubuntu |
| App logs | `/opt/{app_name}/logs` | EBS | {app_name} |
| Runtime data | `/opt/{app_name}/instance` | EBS | {app_name} |
| SSH keys | `/home/ubuntu/.ssh` | Root | ubuntu |
| OS files | `/` | Root | root |

---

## Backup & Restore

### Create Snapshot

```bash
# From AWS Console:
EC2 > Volumes > Select {app_name} volume
→ Actions > Create snapshot

# From CLI:
aws ec2 create-snapshot \
  --volume-id vol-xxxxxxxxx \
  --description "Backup of {app_name}" \
  --region us-east-2
```

### Restore from Snapshot

1. Update configuration with snapshot ID:
   ```yaml
   ebs_volume_snapshot_id: "snap-0123456789abcdef0"
   ```

2. Launch instance:
   ```bash
   cd deployment
   ansible-playbook playbooks/launch-ec2-instance.yml \
       --vault-password-file ~/.vault_pass
   ansible-playbook -i inventories playbooks/setup.yml \
       --vault-password-file ~/.vault_pass
   ```

3. EBS volume will be created from snapshot with all your data

---

## Scaling Storage

### Increase Volume Size

1. **Create snapshot** of current volume

2. **Create larger volume** from snapshot:
   ```bash
   cd deployment
   
   # Update configuration
   ansible-vault edit group_vars/vault.yml --vault-password-file ~/.vault_pass
   # Change: ebs_volume_size: 200    (increase from 100 to 200 GB)
   
   # Create new instance with larger volume
   ansible-playbook playbooks/launch-ec2-instance.yml \
       --vault-password-file ~/.vault_pass
   ansible-playbook -i inventories playbooks/setup.yml \
       --vault-password-file ~/.vault_pass
   ansible-playbook playbooks/launch-ec2-instance.yml
   ```

3. **Or expand existing volume**:
   ```bash
   # Expand volume in AWS Console
   # Then on instance:
   sudo xfs_growfs /{app_name}
   ```

---

## Performance Optimization

### High-Performance Setup

```yaml
ebs_volume_type: "io1"              # High IOPS (expensive)
ec2_instance_type: "t3.small"       # Larger instance
ec2_ebs_optimized: true             # Dedicated throughput
ebs_volume_size: 500                # Larger volume
```

### Cost-Effective Setup

```yaml
ebs_volume_type: "gp3"              # General purpose (recommended)
ec2_instance_type: "t3.micro"       # Free tier
ec2_ebs_optimized: false            # Shared throughput
ebs_volume_size: 100                # Medium size
```

### High-Throughput Setup

```yaml
ebs_volume_type: "st1"              # Throughput optimized
ebs_volume_size: 1000               # 1 TB
ec2_instance_type: "t3.large"       # Larger instance
```

---

## Verification

### Check Mount Point

```bash
# SSH to instance
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@<IP>

# Check mounted volumes
df -h
# Output should show: /{app_name} with configured size

# Check device
lsblk
# Output should show: xvdf1 on /{app_name}
```

### Check Application Location

```bash
# Verify app is on EBS volume
ls -la /{app_name}
# Should show: code, .venv, logs, instance directories

# Check venv
which python
# Should show: /{app_name}/.venv/bin/python

# Check logs on EBS
ls -la /{app_name}/logs
```

### Check fstab

```bash
cat /etc/fstab | grep {app_name}
# Should show: UUID mount for /{app_name}
```

---

## Persistence

### Data Persists

- **Application code** persists on EBS
- **Logs** persist on EBS
- **Cache/data** persists on EBS
- **Virtual environment** persists on EBS

### Across Instance Lifecycle

```
Instance Stop/Start:
  ↓
EBS Volume stays attached
  ↓
All data persists
  ↓
Instance Start:
  ↓
EBS volume auto-mounts (via fstab)
  ↓
Application runs same as before
```

---

## Disaster Recovery

### Quick Recovery

If instance fails:

1. Create new instance with same EBS volume snapshot
2. Attach EBS volume (it auto-mounts)
3. Application starts with all data intact

### Data Protection

- **Encrypted at rest**: AES-256 encryption
- **Snapshots**: Point-in-time backups
- **Versioning**: S3 for code backups
- **Redundancy**: EBS durability

---

## Cost Estimation

### Storage Cost

| Size | Type | Monthly Cost |
|------|------|--------------|
| 100 GB | gp3 | ~$10 |
| 500 GB | gp3 | ~$50 |
| 1 TB | gp3 | ~$100 |
| 100 GB | io1 (3000 IOPS) | ~$35 |
| 500 GB | st1 | ~$23 |

### Total Monthly Cost Example

```
EC2 Instance (t3.micro):     $7.50
Root Volume (20 GB):         Included
App Volume (100 GB gp3):    $10.00
CloudWatch Monitoring:       $3.00
─────────────────────────────────
Total:                      ~$20.50/month
```

---

## Troubleshooting

### Volume Not Mounting

**Problem**: EBS volume not mounted to /{app_name}

**Solution**:
```bash
# Check if volume is visible
lsblk

# Manually mount:
sudo mount /dev/xvdf1 /{app_name}

# Add to fstab if missing:
sudo blkid /dev/xvdf1
# Copy UUID
sudo nano /etc/fstab
# Add: UUID=... /{app_name} xfs defaults,nofail 0 0
```

### Permission Issues

**Problem**: Application cannot write to logs or data

**Solution**:
```bash
# Fix permissions with shared group and setgid
sudo chown -R {app_name}:{app_name} /opt/{app_name}/logs
sudo chown -R {app_name}:{app_name} /opt/{app_name}/instance
sudo chmod 2775 /opt/{app_name}/logs
sudo chmod 2775 /opt/{app_name}/instance
```

### Out of Space

**Problem**: Application volume is full

**Solution**:
```bash
# Check usage
df -h /{app_name}

# Clean old logs
sudo rm /{app_name}/logs/archive/*.log

# Expand volume (see Scaling Storage above)
```

---

## Key Benefits

✅ **Persistence**: Data survives instance stop/restart  
✅ **Scalability**: Add storage without changing instance  
✅ **Backups**: EBS snapshots for point-in-time recovery  
✅ **Performance**: Dedicated storage for application  
✅ **Separation**: OS and application on separate volumes  
✅ **Encryption**: AES-256 encryption at rest  
✅ **Flexibility**: Snapshot restore for migration  
✅ **Cost**: Predictable pricing, only pay for what you use  

---

## See Also

- [USER_MODEL.md](../reference/USER_MODEL.md) - User and permission model

