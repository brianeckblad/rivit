# Security Hardening - Application User Isolation

**Date:** February 14, 2026  
**Status:** ✅ Production-Ready

> **Security Principle:** Applications should run with the minimum privileges necessary to perform their function, not as administrative users.

---

## Quick Reference

### Default Configuration (Secure)

```yaml
# deployment/group_vars/all.yml

app_name: your_app_name           # Your app name (e.g., myapp, inventory_tool, comic_tracker)
app_user: "{{ app_name }}"        # Runtime user (defaults to app_name)
deploy_user: ubuntu               # SSH/deployment user
```

### What This Means

**Runtime User (`{app_name}`):**
- **Runs:** Application process (Gunicorn)
- **Shell:** ❌ None (`/usr/sbin/nologin`)
- **SSH:** ❌ No
- **sudo:** ❌ No
- **Can Read:** Application code
- **Can Write:** Logs, instance data only

**Deploy User (`ubuntu`):**
- **Runs:** Ansible, git, pip
- **Shell:** ✅ Yes (`/bin/bash`)
- **SSH:** ✅ Yes
- **sudo:** ✅ Yes (for ansible)
- **Manages:** Code, dependencies, configs

### Quick Verification Commands

```bash
# Check user configuration
getent passwd {app_name}
# Should show: /usr/sbin/nologin

# Check running process
ps aux | grep gunicorn
# Should show: {app_name} as user

# Test isolation (should fail - good!)
sudo -u {app_name} touch /home/ubuntu/{app_name}/test.txt
# Should fail: Permission denied

# Verify security
systemd-analyze security {app_name}
# Should show: MEDIUM or better

# Check logs
journalctl -u {app_name} -n 50
```

### Security Score

| Feature | Status | Impact |
|---------|--------|--------|
| No SSH Access | ✅ | HIGH |
| No Shell | ✅ | HIGH |
| No sudo | ✅ | HIGH |
| Limited File Write | ✅ | HIGH |
| Systemd Hardening | ✅ | MEDIUM |
| Capability Drop | ✅ | MEDIUM |
| Syscall Filtering | ✅ | MEDIUM |

**Overall: 🛡️ 9/10 - Production-Grade Security**

---

## Overview

This deployment uses a **dedicated, non-privileged application user** with no SSH or shell access, following the **Principle of Least Privilege**. This significantly reduces the attack surface and blast radius if the application is compromised.

## Architecture

### User Separation

```
┌─────────────────────────────────────────────────────────┐
│ Server (EC2/Lightsail)                                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  👤 ubuntu (deploy_user)                                │
│     ├── SSH Access: ✅ YES                              │
│     ├── Shell: /bin/bash                                │
│     ├── sudo: ✅ YES (via Ansible)                      │
│     ├── Purpose: Deployment, git, system management     │
│     └── Home: /home/ubuntu/                             │
│          ├── {app_name}/ (application code)             │
│          └── .venv/ (Python virtual environment)        │
│                                                          │
│  👤 {app_name} (app_user)                               │
│     ├── SSH Access: ❌ NO                               │
│     ├── Shell: /usr/sbin/nologin                        │
│     ├── sudo: ❌ NO                                     │
│     ├── Home: ❌ NONE (system user)                     │
│     ├── Purpose: Run application ONLY                   │
│     └── Permissions:                                    │
│          ├── READ: /home/ubuntu/{app_name}/* (code)     │
│          ├── READ: /home/ubuntu/.venv/* (dependencies)  │
│          ├── WRITE: /var/log/{app_name}/* (logs)        │
│          └── WRITE: /home/ubuntu/{app_name}/instance/* (data)│
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Security Benefits

### 1. **No SSH Access**
- **Attack Vector Eliminated:** App user cannot be used to SSH into the server
- **No Shell:** Even if compromised, attacker has no shell access
- **Impact:** Prevents lateral movement and system exploration

### 2. **Principle of Least Privilege**
- **Minimal Permissions:** App can only read code, write logs/data
- **No System Access:** Cannot modify system files, install packages, or change configs
- **Limited Capabilities:** Systemd removes all unnecessary Linux capabilities

### 3. **Isolation**
- **Separate from Admin:** Deployment user (ubuntu) is isolated from runtime user ({app_name} or your configured app_user)
- **Private Temp:** Application has its own /tmp directory
- **Protected Home:** Cannot access other users' home directories

### 4. **Systemd Security Features**

Our systemd service includes extensive hardening:

```ini
# Prevents privilege escalation
NoNewPrivileges=true

# Private /tmp directory
PrivateTmp=true

# Restrict dangerous system calls
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources @mount

# Make system directories read-only
ProtectSystem=strict
ProtectHome=read-only

# Only these directories are writable
ReadWritePaths=/var/log/{app_name}
ReadWritePaths=/home/ubuntu/{app_name}/instance

# Protect kernel
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true

# Network restrictions
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

# Remove all Linux capabilities
CapabilityBoundingSet=
AmbientCapabilities=

# And 10+ more hardening options...
```

## What Gets Protected

### ✅ Protected Against

| Threat | Protection | How |
|--------|-----------|-----|
| SSH Compromise | ✅ Strong | App user has no shell, cannot SSH |
| Privilege Escalation | ✅ Strong | NoNewPrivileges, no sudo, no capabilities |
| System File Tampering | ✅ Strong | ProtectSystem=strict (read-only /usr, /etc, /boot) |
| Kernel Exploitation | ✅ Strong | Protected kernel logs, modules, tunables |
| Process Spying | ✅ Strong | ProtectProc=invisible |
| Unauthorized Network Access | ✅ Medium | RestrictAddressFamilies (HTTP/HTTPS only) |
| File System Attacks | ✅ Medium | Limited write access to logs and instance data |
| Memory Exploitation | ⚠️ Medium | Memory protections enabled (some exceptions for Python) |

### ⚠️ Application-Level Risks (Not Mitigated by User Isolation)

These require application-level security:
- SQL Injection (if using raw SQL)
- XSS attacks (handled by Flask/Jinja2 auto-escaping)
- CSRF (handled by Flask session management)
- Authentication bypass (handled by app logic)
- Data exfiltration via API (handled by access controls)

## Configuration

### Variables

```yaml
# File: deployment/group_vars/all.yml

# Application user (runs the app, no SSH)
app_user: your_app_name            # Defaults to app_name
                                   # - Created automatically
                                   # - No shell (/usr/sbin/nologin)
                                   # - No home directory
                                   # - System user (UID < 1000)

# Deployment user (SSH, git, ansible)
deploy_user: ubuntu                # Standard EC2/Lightsail user
                                   # - Has SSH access
                                   # - Has sudo (for ansible)
                                   # - Manages code and dependencies

# Paths
app_dir: /home/ubuntu/{app_name}   # Code owned by deploy_user
venv_dir: /home/ubuntu/.venv       # Python venv owned by deploy_user
log_dir: /var/log/{app_name}       # Logs owned by app_user
```

### How It Works

1. **Deployment (as `ubuntu`):**
   ```bash
   # Ansible connects as ubuntu (deploy_user)
   ssh ubuntu@server
   
   # Pulls code, installs dependencies
   cd /home/ubuntu/{app_name}
   git pull
   source ~/.venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Runtime (as `{app_name}`):**
   ```bash
   # Systemd starts service as {app_name} (app_user)
   systemctl start {app_name}
   
   # Process runs as:
   User={app_name}
   Group={app_name}
   WorkingDirectory=/home/ubuntu/{app_name}
   
   # Can only:
   # - Read code files
   # - Write to /var/log/{app_name}/
   # - Write to /home/ubuntu/{app_name}/instance/
   ```

## Verification

### Check User Configuration

```bash
# Verify app user exists and has no shell
getent passwd {app_name}
# Output: {app_name}:x:999:999:Application User (no login):/:/usr/sbin/nologin

# Verify user cannot login
su - {app_name}
# Output: This account is currently not available.

# Check process ownership
ps aux | grep gunicorn
# Output: {app_name}  1234  0.5  2.3  ...  gunicorn
```

### Test Systemd Security

```bash
# Check systemd security analysis
systemd-analyze security {app_name}

# Should show SAFE or MEDIUM ratings for most checks
# Example output:
# ✓ PrivateTmp=yes
# ✓ NoNewPrivileges=yes
# ✓ ProtectSystem=strict
# ✓ ProtectHome=read-only
# Overall exposure level: 2.3 MEDIUM 😀
```

### Verify Permissions

```bash
# App user should NOT be able to write to code directory
sudo -u {app_name} touch /home/ubuntu/{app_name}/test.txt
# Should fail: Permission denied

# App user SHOULD be able to write logs
sudo -u {app_name} touch /var/log/{app_name}/test.log
# Should succeed

# App user SHOULD be able to write instance data
sudo -u {app_name} touch /home/ubuntu/{app_name}/instance/test.json
# Should succeed
```

## Comparison: Before vs After

### Before (Running as ubuntu)

```bash
# ❌ INSECURE: Application runs as ubuntu user

User=ubuntu              # Admin user with SSH access
Shell=/bin/bash         # Full shell available
sudo=YES                # Can escalate privileges (via ansible)
SSH=YES                 # Can SSH to server
Home=/home/ubuntu       # Full access to all deployment files

# If app is compromised:
# - Attacker has SSH user access
# - Can read all code, secrets, keys
# - Can modify deployment files
# - Can potentially escalate to root
# - Can access git credentials
```

### After (Running as {app_name})

```bash
# ✅ SECURE: Application runs as dedicated user

User={app_name}         # Dedicated app user
Shell=/usr/sbin/nologin # No shell access
sudo=NO                 # No privilege escalation
SSH=NO                  # Cannot SSH
Home=NONE              # No home directory

# If app is compromised:
# - Attacker has limited process access only
# - Cannot modify code or system files
# - Cannot install packages or change configs
# - Cannot SSH or get shell
# - Contained to log and data directories
# - No lateral movement possible
```

## Migration Guide

### For New Deployments

No action needed! The secure user is created automatically during setup:

```bash
ansible-playbook -i inventories/production playbooks/setup.yml
```

### For Existing Deployments

If you're already running with `app_user: ubuntu`, you can migrate:

**Option 1: Redeploy (Recommended)**
1. Backup your data
2. Update configuration to use new user
3. Run setup playbook
4. Restore data

**Option 2: Keep Existing (Less Secure)**
Keep using `ubuntu` user by not changing the config:
```yaml
# deployment/group_vars/production/vars.yml
app_user: ubuntu
deploy_user: ubuntu
```

---

## Migration Guide

### For Existing Deployments

If you're already running with `app_user: ubuntu`, you can migrate to the secure configuration:

#### Option 1: Migrate to Dedicated User (Recommended)

**Time Required:** 15-30 minutes  
**Downtime:** 2-5 minutes (during service restart)

**Steps:**

1. **Backup instance data**
   ```bash
   ssh ubuntu@your-server
   cd /home/ubuntu/{app_name}
   tar -czf ~/instance-backup-$(date +%Y%m%d-%H%M%S).tar.gz instance/
   ```

2. **Pull latest code**
   ```bash
   ssh ubuntu@your-server
   cd /home/ubuntu/{app_name} && git pull
   ```

3. **Run setup playbook** (creates dedicated user)
   ```bash
   # On your local machine
   cd deployment
   ansible-playbook -i inventories/production playbooks/setup.yml
   ```

4. **Fix permissions**
   ```bash
   ssh ubuntu@your-server
   
   # Code directory (deploy_user owns)
   sudo chown -R ubuntu:ubuntu /home/ubuntu/{app_name}
   
   # Log directory (app_user owns)
   sudo chown -R {app_name}:{app_name} /var/log/{app_name}
   
   # Instance directory (app_user owns)
   sudo chown -R {app_name}:{app_name} /home/ubuntu/{app_name}/instance
   ```

5. **Restart service**
   ```bash
   ssh ubuntu@your-server
   sudo systemctl daemon-reload
   sudo systemctl restart {app_name}
   ```

6. **Verify**
   ```bash
   # User exists with no shell
   getent passwd {app_name}
   # Should show: /usr/sbin/nologin
   
   # Process runs as {app_name}
   ps aux | grep gunicorn
   # Should show: {app_name}
   
   # Security score
   systemd-analyze security {app_name}
   # Should show: MEDIUM or better
   ```

#### Option 2: Keep Existing Configuration (Less Secure)

To continue using ubuntu user:
```yaml
# deployment/group_vars/production/vars.yml
app_user: ubuntu
deploy_user: ubuntu
```

**Note:** This is less secure but requires no changes.

---

## Troubleshooting

### Permission Denied Errors

```bash
# Problem: App cannot read code files
# Solution: Ensure deploy_user owns code directory
sudo chown -R ubuntu:ubuntu /home/ubuntu/{app_name}

# Problem: App cannot write logs
# Solution: Ensure app_user owns log directory
sudo chown -R {app_name}:{app_name} /var/log/{app_name}
sudo chmod 755 /var/log/{app_name}

# Problem: App cannot write instance data
# Solution: Ensure app_user owns instance directory
sudo chown -R {app_name}:{app_name} /home/ubuntu/{app_name}/instance
sudo chmod 755 /home/ubuntu/{app_name}/instance
```

### Service Won't Start

```bash
# Check systemd status
systemctl status {app_name}

# Check if user exists
getent passwd {app_name}

# Check permissions
namei -l /home/ubuntu/{app_name}
namei -l /var/log/{app_name}

# View detailed logs
journalctl -u {app_name} -n 50 --no-pager
```

### Systemd Security Warnings

Some systemd security warnings are expected:

```bash
# This is OK - Python needs to load dynamic libraries
MemoryDenyWriteExecute=no

# This is OK - We need read access to code
ProtectHome=read-only  # (not ProtectHome=yes)

# This is OK - We need write access to specific dirs
ProtectSystem=strict with ReadWritePaths
```

## Additional Hardening Options

### Consider for Maximum Security

1. **AppArmor/SELinux Profile**
   - Confine app to specific file operations
   - Prevents unauthorized file access

2. **Seccomp-BPF Filter**
   - Custom syscall filtering
   - Block dangerous operations at kernel level

3. **Namespace Isolation**
   - PID namespace (PrivatePID=true)
   - Network namespace (PrivateNetwork=true with proxy)
   - Requires systemd 232+

4. **Read-Only Root Filesystem**
   - ProtectSystem=strict + ReadOnlyPaths=/
   - Requires careful configuration

## References

- [Systemd Security Options](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Security)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [OWASP - Principle of Least Privilege](https://owasp.org/www-community/Access_Control)
- [CIS Ubuntu Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)

---

## Summary

✅ **Application runs as dedicated user with:**
- No SSH access
- No shell access
- No sudo privileges
- Minimal file permissions
- Extensive systemd security hardening

✅ **Deployment managed by separate user:**
- ubuntu user handles git, pip, ansible
- Keeps deployment and runtime separated

✅ **Defense in Depth:**
- Even if app is compromised, attacker is contained
- Cannot escalate privileges or access system
- Limited blast radius

**This is production-grade security following industry best practices.**

