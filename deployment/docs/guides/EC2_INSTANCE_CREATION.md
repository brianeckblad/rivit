# EC2 Instance Creation Configuration

**Date:** February 21, 2026  
**Status:** ✅ Fully Enhanced

## Overview

Your deployment now creates EC2 instances with all essential options configured automatically:

- ✅ Public IP assignment
- ✅ Security groups with rules (SSH, HTTP, HTTPS)
- ✅ SSH key pairs for authentication
- ✅ IAM instance profiles for AWS access
- ✅ CloudWatch monitoring
- ✅ EBS volume configuration
- ✅ Comprehensive instance information

---

## Instance Creation Playbooks

### 1. **create-ssh-key.yml**
Creates SSH key pair for server access

**What it does:**
- Creates RSA 2048-bit SSH key in AWS
- Saves private key locally: `~/.ssh/{app_name}-key.pem`
- Sets permissions to 0400 (read-only)
- Provides key fingerprint and security warnings

**File created:**
```bash
~/.ssh/{app_name}-key.pem
```

**Security Notes:**
- Private key is generated ONCE and saved locally
- AWS doesn't store the private key
- Never commit to git
- If lost, cannot access instance (without Systems Manager)

---

### 2. **create-security-group.yml**
Creates security group with firewall rules

**What it does:**
- Creates security group: `{app_name}-sg`
- Opens port 22 (SSH) - for server administration
- Opens port 80 (HTTP) - for web traffic
- Opens port 443 (HTTPS) - for secure web traffic
- Allows all outbound traffic (for package updates, APIs)

**Ingress Rules:**
```yaml
Port 22:    SSH  (0.0.0.0/0)  # All sources
Port 80:    HTTP (0.0.0.0/0)  # All sources
Port 443:   HTTPS(0.0.0.0/0)  # All sources
```

**Egress Rules:**
```yaml
All traffic to 0.0.0.0/0  # Allow outbound to anywhere
```

**Security Note:**
SSH (port 22) is open to all sources (`0.0.0.0/0`). For production, consider restricting to your office/home IP.

---

### 3. **create-iam-role.yml**
Creates IAM role for AWS service access

**What it does:**
- Creates IAM role: `{app_name}-ec2-role`
- Attaches S3 bucket access
- Attaches Secrets Manager access
- Attaches CloudWatch access
- Attaches SSM for Systems Manager

**Permissions granted:**
- S3: Read, write, delete objects
- Secrets Manager: Read secrets
- CloudWatch: Write logs, metrics
- SSM: Systems Manager access (no SSH key needed)

---

### 4. **launch-ec2-instance.yml**
Launches EC2 instance with all configuration

**What it does:**
- Gets latest Ubuntu 22.04 LTS AMI
- Launches instance with:
  - Specified instance type (default: t3.micro)
  - Public IP assignment (automatic)
  - Security group with firewall rules
  - SSH key pair for access
  - IAM instance profile for AWS access
  - EBS volumes (root + optional data)
  - CloudWatch monitoring (detailed)
  - Comprehensive instance tags

**Instance Configuration:**
```yaml
Root Volume:          20 GB (gp3, encrypted)
Public IP:            Assigned automatically
Security Group:       {app_name}-sg
IAM Role:             {app_name}-ec2-role
SSH Key:              {app_name}-key.pem
Monitoring:           Enabled (detailed metrics)
Source/Dest Check:    Enabled
Termination Protect:  Disabled (enable for production)
EBS Optimized:        Disabled (enable for high-performance storage)
```

**Output:**
- Instance ID
- Public IP address
- Private IP address
- VPC and Subnet IDs
- Comprehensive instance-info.txt file

---

## Full Instance Configuration

### Networking
```yaml
assign_public_ip: yes              # Public IP is assigned
source_dest_check: yes             # Source/destination checking enabled
vpc_id: auto                       # Uses default VPC
subnet_id: auto                    # Uses default subnet
security_group: {app_name}-sg      # Custom security group
```

### Storage
```yaml
root_volume:                       # 20 GB gp3 (encrypted)
  device_name: /dev/xvda
  size: 20 GB
  type: gp3
  encrypted: yes

data_volume (optional):            # If enable_ebs_volume: true
  device_name: /dev/sdf
  size: configurable (default: 100 GB)
  type: configurable (default: gp3)
  encrypted: yes
```

### Monitoring & Management
```yaml
monitoring: yes                    # CloudWatch detailed monitoring
disable_api_termination: no        # Termination allowed (change to yes for production)
ebs_optimized: no                  # Regular EBS (yes for high-performance)
```

### Access
```yaml
key_name: {app_name}-key           # SSH key pair
iam_instance_profile: {app_name}-instance-profile
admin_user: ubuntu                 # Default user for Ubuntu AMI
```

---

## Instance Information Output

After creation, you'll see comprehensive information including:

### Display Output
```
Instance ID:          i-0123456789abcdef0
Instance Name:        myapp
Instance Type:        t3.micro
Instance State:       running
Availability Zone:    us-east-2a

Public IP Address:    203.0.113.42
Private IP Address:   172.31.0.10
VPC ID:               vpc-0123456789abcdef0
Subnet ID:            subnet-0123456789abcdef0
Security Groups:      myapp-sg

SSH Command:
  ssh -i ~/.ssh/myapp-key.pem ubuntu@203.0.113.42
```

### Saved to File
```bash
deployment/instance-info.txt
```

This file contains:
- Complete instance details
- Networking information
- Security configuration
- Storage details
- SSH access instructions
- AWS CLI commands
- Cost estimates
- Deployment next steps
- Important security notes

---

## Common Configuration Options

### Small Application (1-10 concurrent users)
```yaml
ec2_instance_type: "t3.micro"      # AWS free tier
ebs_volume_size: 100               # 100 GB data volume
cloudfront_price_class: "PriceClass_100"
```

### Medium Application (10-100 concurrent users)
```yaml
ec2_instance_type: "t3.small"      # $0.023/hour
ebs_volume_size: 500               # 500 GB data volume
monitoring: yes                    # Detailed monitoring
```

### High-Traffic Application (100+ concurrent users)
```yaml
ec2_instance_type: "t3.large"      # $0.092/hour
ebs_optimized: yes                 # High-performance storage
ebs_volume_type: "io1"             # High IOPS
disable_api_termination: yes       # Protect from accidental termination
```

### Database Server
```yaml
ec2_instance_type: "t3.medium"
ebs_volume_type: "io1"             # High IOPS for database
ebs_volume_size: 1000              # 1 TB for database
ebs_volume_mount_path: "/var/lib/postgresql"
disable_api_termination: yes
```

---

## Security Best Practices

### SSH Access
**Current:**
- Port 22 open to all sources (0.0.0.0/0)

**Recommendation for Production:**
1. Restrict SSH to your IP only:
   ```
   22 (SSH): Your.IP.Address/32
   ```

2. Or use AWS Systems Manager Session Manager:
   ```bash
   aws ssm start-session --target i-0123456789abcdef0
   # No SSH key needed, no open SSH port
   ```

3. Or use bastion host (jump server):
   ```
   Restrict SSH to bastion host IP only
   ```

### IAM Instance Profile
- Has only necessary permissions (S3, Secrets Manager, CloudWatch, SSM)
- No admin access
- Follows principle of least privilege

### Encryption
- Root volume encrypted (AES-256)
- EBS data volume encrypted (AES-256)
- Encryption at rest by default

### Tags
- Every instance tagged with application name
- Tagged with creation date
- Tagged for easy identification and billing

---

## Next Steps After Instance Creation

### 1. Verify Instance Is Running
```bash
# AWS Console: EC2 > Instances
# Or via CLI:
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef0 \
  --region us-east-2
```

### 2. Check Status Checks
```
AWS Console > EC2 > Instances > Instance
Wait for both status checks to pass (usually 1-2 minutes)
```

### 3. Test SSH Access
```bash
ssh -i ~/.ssh/myapp-key.pem ubuntu@203.0.113.42
```

### 4. Update Ansible Inventory
```yaml
# deployment/inventories/hosts.yml
server:
  ansible_host: 203.0.113.42  # Your instance IP
```

### 5. Run Application Setup
```bash
ansible-playbook -i inventories playbooks/setup.yml
```

### 6. Verify Application
```bash
curl http://203.0.113.42
```

---

## Useful AWS CLI Commands

### Get Instance Details
```bash
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef0 \
  --region us-east-2 \
  --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress,State.Name]'
```

### Stop Instance (keep EBS volumes)
```bash
aws ec2 stop-instances \
  --instance-ids i-0123456789abcdef0 \
  --region us-east-2
```

### Start Instance
```bash
aws ec2 start-instances \
  --instance-ids i-0123456789abcdef0 \
  --region us-east-2
```

### Terminate Instance (DELETE)
```bash
aws ec2 terminate-instances \
  --instance-ids i-0123456789abcdef0 \
  --region us-east-2
```

### Enable Termination Protection (Production)
```bash
aws ec2 modify-instance-attribute \
  --instance-id i-0123456789abcdef0 \
  --disable-api-termination \
  --region us-east-2
```

### Create Snapshot of Volume
```bash
aws ec2 create-snapshot \
  --volume-id vol-0123456789abcdef0 \
  --description "Backup before upgrade" \
  --region us-east-2
```

### Connect without SSH (Systems Manager)
```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --region us-east-2
```

---

## Cost Estimation

### EC2 Instance
| Type | Cost/hour | Cost/month |
|------|-----------|-----------|
| t3.micro | $0.0104 | ~$7.50 |
| t3.small | $0.0208 | ~$15 |
| t3.medium | $0.0416 | ~$30 |
| t3.large | $0.0832 | ~$60 |

### Storage
| Type | Size | Cost/month |
|------|------|-----------|
| gp3 | 100 GB | ~$10 |
| gp3 | 500 GB | ~$50 |
| gp3 | 1 TB | ~$100 |

### CloudWatch
| Component | Cost/month |
|-----------|-----------|
| Detailed Monitoring | ~$3 |
| Logs Ingestion | ~$0.50/GB |
| Alarms | Free (10 free) |

### Total Example (t3.micro + 100GB EBS)
```
EC2 Instance:      $7.50
Root Volume (20GB):  Included in EC2
Data Volume (100GB): $10
CloudWatch:         $3
---
Total:            ~$20/month
```

---

## Troubleshooting

### Instance Won't Start
1. Check security group allows SSH (port 22)
2. Check IAM role has proper permissions
3. Check instance state checks in AWS Console
4. Review instance logs: `aws ec2 get-console-output --instance-id ...`

### Can't SSH to Instance
1. Verify SSH key permissions: `chmod 0400 ~/.ssh/myapp-key.pem`
2. Verify public IP is assigned
3. Verify security group allows port 22
4. Verify instance status checks passed
5. Use Systems Manager if SSH not working: `aws ssm start-session ...`

### EBS Volume Not Mounting
1. Run `lsblk` on instance to check if volume is visible
2. Check setup.yml logs for formatting errors
3. Manually mount: `sudo mount /dev/xvdf1 /data`

---

## See Also

- [PREREQUISITES.md](PREREQUISITES.md) - Setup guide
- [ARCHITECTURE.md](../reference/ARCHITECTURE.md) - System architecture
- [EBS_STORAGE.md](../reference/EBS_STORAGE.md) - EBS configuration
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

