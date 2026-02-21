# Ansible Inventory Configuration (hosts.yml)

**File Location:** `deployment/inventories/hosts.yml`
**Purpose:** Tell Ansible which server(s) to deploy to
**When to change:** After launching EC2 instance

---

## Overview

The `hosts.yml` file is an Ansible inventory file that specifies:
- Where your server is located (IP address or domain)
- How to connect to it (SSH user, key, etc.)
- Any server-specific variables

---

## Setup Process

### Step 1: Understand the Default Template

```yaml
all:
  hosts:
    server:
      # ⚠️ CHANGE THIS: Replace with your EC2 instance IP or domain
      ansible_host: localhost           # ⚠️ UPDATE THIS - Your server IP address

      # For local testing only:
      ansible_connection: local         # Remove this line for remote server

      # For remote server, uncomment these:
      # ansible_user: ubuntu
      # ansible_ssh_private_key_file: ~/.ssh/{app_name}-key.pem

  vars:
    # Auto-configured (do not change)
    ansible_user: ubuntu
    ansible_python_interpreter: /usr/bin/python3
```

### Step 2: After Launching EC2 Instance

After your EC2 instance is created:

```bash
# Update hosts.yml with your EC2 instance IP
nano deployment/inventories/hosts.yml
```

Change:
```yaml
ansible_host: localhost
```

To:
```yaml
ansible_host: 1.2.3.4  # Replace with your actual EC2 IP
```

---

## Configuration Variables

### `ansible_host` (REQUIRED)

**Purpose:** Where to find your server

**For Local Testing:**
```yaml
ansible_host: localhost
ansible_connection: local
```

**For Remote EC2 Instance:**
```yaml
ansible_host: 1.2.3.4              # Use your EC2 instance's IP address
# OR
ansible_host: myapp.example.com    # Or your domain name
```

**How to find your EC2 IP:**
1. Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2/)
2. Find your instance (named `{app_name}`)
3. Note the "Public IPv4 address" (e.g., `1.2.3.4`)
4. Copy this into `ansible_host`

---

### `ansible_connection` (Optional)

**Purpose:** How to connect to the server

**For Local Testing Only:**
```yaml
ansible_connection: local
```

**For Remote Server:**
- Remove this line entirely
- Default SSH connection is used

---

### `ansible_user` (Optional for Remote)

**Purpose:** Which user to SSH in as

**Default:** `ubuntu` (correct for Ubuntu 22.04 EC2 AMI)

**When to change:** Only if using a different OS or custom AMI

**Location:** Can be set globally under `vars:` section
```yaml
vars:
  ansible_user: ubuntu
```

---

### `ansible_ssh_private_key_file` (Required for Remote)

**Purpose:** Path to your SSH key file

**For Remote Server:**
```yaml
ansible_ssh_private_key_file: ~/.ssh/{app_name}-key.pem
```

**Replace `{app_name}` with your actual app name:**
- Example: `~/.ssh/myapp-key.pem`
- Example: `~/.ssh/comic_tracker-key.pem`

**Key Location:**
- Should be in `~/.ssh/` directory
- File created during "Create SSH Key Pair" deployment step
- Permissions must be `600`: `chmod 600 ~/.ssh/{app_name}-key.pem`

**Uncomment this line:**
```yaml
# Change FROM:
# ansible_ssh_private_key_file: ~/.ssh/{app_name}-key.pem

# Change TO:
ansible_ssh_private_key_file: ~/.ssh/{app_name}-key.pem
```

---

### `ansible_python_interpreter` (Already Set)

**Purpose:** Which Python to use on remote server

**Default:** `/usr/bin/python3` (correct for Ubuntu)

**Don't change:** This is already configured correctly

---

## Complete Examples

### Example 1: Local Testing Setup

```yaml
all:
  hosts:
    server:
      ansible_host: localhost
      ansible_connection: local

  vars:
    ansible_user: ubuntu
    ansible_python_interpreter: /usr/bin/python3
```

### Example 2: Remote EC2 Instance

```yaml
all:
  hosts:
    server:
      ansible_host: 1.2.3.4  # Your EC2 instance IP
      ansible_ssh_private_key_file: ~/.ssh/myapp-key.pem

  vars:
    ansible_user: ubuntu
    ansible_python_interpreter: /usr/bin/python3
```

### Example 3: Remote with Domain Name

```yaml
all:
  hosts:
    server:
      ansible_host: myapp.example.com  # Your domain
      ansible_ssh_private_key_file: ~/.ssh/myapp-key.pem

  vars:
    ansible_user: ubuntu
    ansible_python_interpreter: /usr/bin/python3
```

---

## Step-by-Step: Update After Deployment

### 1. Get Your EC2 Instance IP

```bash
# Option A: AWS Console (Recommended)
# Go to: https://console.aws.amazon.com/ec2/
# Find your instance, copy the "Public IPv4 address"

# Option B: AWS CLI
aws ec2 describe-instances \
  --region us-east-2 \
  --filters "Name=tag:Name,Values=myapp" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### 2. Update hosts.yml

```bash
nano deployment/inventories/hosts.yml
```

Change:
```yaml
ansible_host: localhost
ansible_connection: local
```

To:
```yaml
ansible_host: 1.2.3.4  # Your actual IP
```

And uncomment the SSH section:
```yaml
# Change FROM:
# ansible_user: ubuntu
# ansible_ssh_private_key_file: ~/.ssh/{app_name}-key.pem

# Change TO:
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/{app_name}-key.pem
```

### 3. Verify SSH Key File Exists

```bash
# Replace {app_name} with your actual app name
ls -la ~/.ssh/{app_name}-key.pem

# Should show:
# -rw------- (permissions 600)
```

If missing, recreate it:
```bash
# Download from AWS Console or recreate with:
ansible-playbook playbooks/create-ssh-key.yml
```

### 4. Test Connection

```bash
# Test SSH connection to your server
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@1.2.3.4

# If successful, you should see:
# ubuntu@myapp-server:~$
```

### 5. Now Ready for Deployment

```bash
# Deploy to remote server
ansible-playbook playbooks/setup.yml
```

---

## Troubleshooting

### Error: "Permission denied (publickey)"

**Problem:** SSH key permissions are wrong

**Solution:**
```bash
chmod 600 ~/.ssh/{app_name}-key.pem
```

### Error: "No hosts matched"

**Problem:** Ansible can't find the server

**Check:**
- Is `ansible_host` set correctly? (IP or domain)
- Is the server running? (Check AWS Console)
- Can you ping it? `ping 1.2.3.4`

### Error: "Connection timed out"

**Problem:** Can't reach the server

**Check:**
- Is security group allowing SSH (port 22)?
- Is the instance's IP address correct?
- Are you on the correct network/VPN?

### Error: "ansible_ssh_private_key_file: ~/.ssh/..."

**Problem:** File path is incorrect or file doesn't exist

**Solution:**
- Use full path: `/Users/your_username/.ssh/{app_name}-key.pem`
- Or: `~/.ssh/{app_name}-key.pem` (~ expands to home directory)
- Check file exists: `ls ~/.ssh/{app_name}-key.pem`

---

## When to Change hosts.yml

| Situation | Change Required |
|-----------|-----------------|
| First deployment (local) | No changes (use localhost) |
| Deploy to EC2 instance | ✅ YES - Update ansible_host + add SSH key |
| Change server | ✅ YES - Update ansible_host to new IP |
| Replace SSH key | ✅ YES - Update ansible_ssh_private_key_file |
| Move to different domain | ✅ YES - Update ansible_host to new domain |
| Test playbooks locally | ✅ Use local template (don't change for remote) |

---

## Summary

**Quick Checklist:**

- [ ] After launching EC2 instance
- [ ] Get instance public IP from AWS Console
- [ ] Update `ansible_host: 1.2.3.4` with your IP
- [ ] Uncomment SSH user line
- [ ] Update SSH key path: `~/.ssh/{app_name}-key.pem`
- [ ] Verify SSH key file exists and has 600 permissions
- [ ] Test SSH connection works
- [ ] Now ready to run deployment playbooks

---

**File Location:** `deployment/inventories/hosts.yml`
**Last Updated:** February 20, 2026
**Status:** ✅ Production Ready

