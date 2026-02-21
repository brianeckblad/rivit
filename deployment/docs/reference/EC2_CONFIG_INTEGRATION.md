# EC2 Configuration Integration Map

## Variable → Code → Documentation → Output

This document shows how EC2 configuration flows through the entire system.

---

## 1. PUBLIC IP ASSIGNMENT

**Variable Definition** (all.yml.example)
```yaml
# assign_public_ip: true                         # Assign public IP automatically (default: true)
#                                                 # Must be true for SSH/HTTP/HTTPS access
```

**Variable Default** (all.yml)
```yaml
assign_public_ip: "{{ assign_public_ip | default(true) }}"
```

**Code Usage** (launch-ec2-instance.yml)
```yaml
assign_public_ip: "{{ assign_public_ip }}"
```

**Instance Tag** (launch-ec2-instance.yml)
```yaml
PublicIP: "{{ 'Yes' if assign_public_ip else 'No' }}"
```

**Instance Info Output** (instance-info.txt)
```
Assign Public IP:         Yes
Public IP Address:        203.0.113.42
```

**Documentation**
- EC2_INSTANCE_CREATION.md (networking section)
- EC2_FEATURES_CHECKLIST.md (public IP section)

---

## 2. CLOUDWATCH MONITORING

**Variable Definition** (all.yml.example)
```yaml
# ec2_monitoring_enabled: true                   # Enable CloudWatch detailed monitoring (default: true)
#                                                 # Provides detailed metrics (1-minute intervals)
#                                                 # Cost: ~$3/month
```

**Variable Default** (all.yml)
```yaml
ec2_monitoring_enabled: "{{ ec2_monitoring_enabled | default(true) }}"
```

**Code Usage** (launch-ec2-instance.yml)
```yaml
monitoring: "{{ ec2_monitoring_enabled }}"
```

**Instance Tag** (launch-ec2-instance.yml)
```yaml
Monitoring: "{{ 'Enabled' if ec2_monitoring_enabled else 'Disabled' }}"
```

**Instance Info Output** (instance-info.txt)
```
CloudWatch Monitoring:    Enabled (detailed metrics)
```

**Documentation**
- EC2_INSTANCE_CREATION.md (monitoring section)
- EC2_FEATURES_CHECKLIST.md (monitoring section)

---

## 3. TERMINATION PROTECTION

**Variable Definition** (all.yml.example)
```yaml
# ec2_termination_protection: false              # Protect instance from accidental termination (default: false)
#                                                 # Set to true for production to prevent accidental deletion
#                                                 # You can still manually delete if you disable protection first
```

**Variable Default** (all.yml)
```yaml
ec2_termination_protection: "{{ ec2_termination_protection | default(false) }}"
```

**Code Usage** (launch-ec2-instance.yml)
```yaml
disable_api_termination: "{{ ec2_termination_protection }}"
```

**Instance Tag** (launch-ec2-instance.yml)
```yaml
TerminationProtection: "{{ 'Yes' if ec2_termination_protection else 'No' }}"
```

**Instance Info Output** (instance-info.txt)
```
Termination Protection:   Disabled
Enable termination protection:
  aws ec2 modify-instance-attribute --instance-id ... --disable-api-termination
```

**Documentation**
- EC2_INSTANCE_CREATION.md (management section)
- EC2_FEATURES_CHECKLIST.md (management section)

---

## 4. EBS OPTIMIZATION

**Variable Definition** (all.yml.example)
```yaml
# ec2_ebs_optimized: false                       # Enable EBS optimization (default: false)
#                                                 # Provides dedicated throughput to EBS
#                                                 # Recommended for I/O intensive applications
#                                                 # Adds ~5-10% to instance cost
```

**Variable Default** (all.yml)
```yaml
ec2_ebs_optimized: "{{ ec2_ebs_optimized | default(false) }}"
```

**Code Usage** (launch-ec2-instance.yml)
```yaml
ebs_optimized: "{{ ec2_ebs_optimized }}"
```

**Instance Info Output** (instance-info.txt)
```
EBS Optimization:         Disabled
```

**Documentation**
- EC2_INSTANCE_CREATION.md (storage section)
- EC2_FEATURES_CHECKLIST.md (storage section)

---

## 5. SOURCE/DESTINATION CHECK

**Variable Definition** (all.yml.example)
```yaml
# ec2_source_dest_check: true                    # Enable source/destination check (default: true)
#                                                 # Security feature: validates packet source/destination
#                                                 # Required for normal EC2 operation
#                                                 # Only disable if using instance as NAT/proxy
```

**Variable Default** (all.yml)
```yaml
ec2_source_dest_check: "{{ ec2_source_dest_check | default(true) }}"
```

**Code Usage** (launch-ec2-instance.yml)
```yaml
source_dest_check: "{{ ec2_source_dest_check }}"
```

**Instance Info Output** (instance-info.txt)
```
Source/Dest Check:        Enabled
```

**Documentation**
- EC2_INSTANCE_CREATION.md (networking section)
- EC2_FEATURES_CHECKLIST.md (networking section)

---

## 6. EBS VOLUMES

**Variable Definitions** (all.yml.example)
```yaml
# enable_ebs_volume: false
# ebs_volume_size: 100
# ebs_volume_type: "gp3"
# ebs_volume_mount_path: "/data"
# ebs_volume_encrypted: true
# ebs_volume_snapshot_id: ""
```

**Variable Defaults** (all.yml)
```yaml
enable_ebs_volume: "{{ enable_ebs_volume | default(false) }}"
ebs_volume_size: "{{ ebs_volume_size | default(100) }}"
ebs_volume_type: "{{ ebs_volume_type | default('gp3') }}"
ebs_volume_mount_path: "{{ ebs_volume_mount_path | default('/data') }}"
ebs_volume_encrypted: "{{ ebs_volume_encrypted | default(true) }}"
ebs_volume_snapshot_id: "{{ ebs_volume_snapshot_id | default('') }}"
ebs_device_name: "/dev/sdf"
```

**Code Usage** (launch-ec2-instance.yml)
```yaml
instance_volumes: "{{ [{'device_name': '/dev/xvda', ...}] + ([{'device_name': ebs_device_name, 'ebs': {...}}] if enable_ebs_volume | bool else []) }}"
```

**Code Usage** (setup.yml)
```yaml
- name: Check if EBS volume is attached
  block:
    - name: List available block devices
    - name: Find EBS volume device
    - name: Create filesystem on EBS volume
    - name: Mount EBS volume
    # ... more mounting tasks
```

**Instance Tag** (launch-ec2-instance.yml)
```yaml
EBSVolume: "{{ 'Attached' if enable_ebs_volume else 'None' }}"
```

**Instance Info Output** (instance-info.txt)
```
Data Volume:
  Device Name:            /dev/sdf
  Size:                   100 GB
  Type:                   gp3
  Mount Path:             /data
```

**Documentation**
- EBS_STORAGE.md (comprehensive EBS guide)
- EBS_QUICK_START.md (quick reference)
- EC2_INSTANCE_CREATION.md (storage section)
- EC2_FEATURES_CHECKLIST.md (storage section)

---

## 7. SECURITY GROUP

**Configuration** (create-security-group.yml)
```yaml
rules:
  - proto: tcp
    from_port: 22
    to_port: 22
    cidr_ip: 0.0.0.0/0
    rule_desc: "SSH - Server administration"
  
  - proto: tcp
    from_port: 80
    to_port: 80
    cidr_ip: 0.0.0.0/0
    rule_desc: "HTTP - Web traffic"
  
  - proto: tcp
    from_port: 443
    to_port: 443
    cidr_ip: 0.0.0.0/0
    rule_desc: "HTTPS - Secure web traffic"
```

**Instance Info Output** (instance-info.txt)
```
Security Groups:          myapp-sg

Ingress Rules:
  • SSH (22):         All sources (0.0.0.0/0)
  • HTTP (80):        All sources (0.0.0.0/0)
  • HTTPS (443):      All sources (0.0.0.0/0)
```

**Documentation**
- EC2_INSTANCE_CREATION.md (security section)
- EC2_FEATURES_CHECKLIST.md (security section)

---

## 8. SSH KEY PAIR

**Configuration** (create-ssh-key.yml)
```yaml
- name: Create SSH key pair in AWS
  amazon.aws.ec2_key:
    name: "{{ app_name }}-key"
    region: "{{ aws_region }}"

- name: Save private key locally
  copy:
    content: "{{ key_pair.key.private_key }}"
    dest: "~/.ssh/{{ app_name }}-key.pem"
    mode: '0400'
```

**Instance Info Output** (instance-info.txt)
```
SSH Key Name:             myapp-key
SSH Key Location:         ~/.ssh/myapp-key.pem
SSH Key Permissions:      0400 (read-only)

SSH Command:
  ssh -i ~/.ssh/myapp-key.pem ubuntu@203.0.113.42
```

**Documentation**
- EC2_INSTANCE_CREATION.md (security section)
- EC2_FEATURES_CHECKLIST.md (security section)

---

## 9. IAM INSTANCE PROFILE

**Configuration** (create-iam-role.yml)
```yaml
- name: Create IAM role for EC2 instance
  community.aws.iam_role:
    name: "{{ app_name }}-ec2-role"
    
- name: Attach S3 access policy to role
- name: Attach Secrets Manager access policy to role
- name: Attach CloudWatch access policy to role
- name: Attach SSM access policy to role
```

**Instance Info Output** (instance-info.txt)
```
IAM Instance Role:        myapp-ec2-role

Permissions:
  • S3 access (read, write, delete, list)
  • Secrets Manager access (read)
  • CloudWatch access (write logs, metrics)
  • SSM access (Systems Manager)
```

**Documentation**
- EC2_INSTANCE_CREATION.md (security section)
- EC2_FEATURES_CHECKLIST.md (security section)

---

## File Locations Reference

| Component | Variable File | Code File | Documentation |
|-----------|---------------|-----------|----------------|
| Configuration | all.yml.example | launch-ec2-instance.yml | EC2_INSTANCE_CREATION.md |
| Public IP | all.yml | launch-ec2-instance.yml | EC2_FEATURES_CHECKLIST.md |
| Monitoring | all.yml | launch-ec2-instance.yml | EC2_FEATURES_CHECKLIST.md |
| Termination Protect | all.yml | launch-ec2-instance.yml | EC2_FEATURES_CHECKLIST.md |
| EBS Optimization | all.yml | launch-ec2-instance.yml | EC2_FEATURES_CHECKLIST.md |
| Source/Dest Check | all.yml | launch-ec2-instance.yml | EC2_FEATURES_CHECKLIST.md |
| EBS Volume | all.yml | launch-ec2-instance.yml, setup.yml | EBS_STORAGE.md, EBS_QUICK_START.md |
| Security Group | N/A (hardcoded ports) | create-security-group.yml | EC2_INSTANCE_CREATION.md |
| SSH Key | N/A (variable: app_name) | create-ssh-key.yml | EC2_INSTANCE_CREATION.md |
| IAM Role | N/A (variable: app_name) | create-iam-role.yml | EC2_INSTANCE_CREATION.md |

---

## How Configuration Flows

```
1. USER VIEWS OPTIONS
   ↓
   deployment/group_vars/all.yml.example
   (Shows all options with explanations and defaults)

2. USER CUSTOMIZES
   ↓
   Uncomments/edits deployment/group_vars/all.yml
   (Sets custom values or leaves defaults)

3. ANSIBLE RUNS
   ↓
   deployment/playbooks/launch-ec2-instance.yml
   (Reads variables from all.yml)

4. INSTANCE CREATED
   ↓
   AWS EC2 instance with configured options
   (All EC2 settings applied as specified)

5. CONFIRMATION
   ↓
   Console output + deployment/instance-info.txt
   (Shows all configured values)

6. USER VERIFIES
   ↓
   deployment/docs/guides/EC2_INSTANCE_CREATION.md
   (Reference documentation for verification)
```

---

## Summary

✅ **All EC2 features are integrated:**
- Variables defined in configuration files
- Code uses variables from configuration
- Documentation explains all options
- Output shows configured values
- Easy to customize for different scenarios

✅ **No information is duplicated:**
- Single source of truth (all.yml)
- Variables referenced in playbooks
- Documentation links to configurations

✅ **Easy to use and maintain:**
- Clear variable names
- Comprehensive documentation
- Sensible defaults
- Easy to override

Everything is interconnected and working together!

