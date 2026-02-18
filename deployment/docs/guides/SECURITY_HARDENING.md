# Security Hardening Guide

**Secure your server and application**

---

## Overview

Security hardening means making your server resistant to attacks. Think of it like:
- Locking doors (close unnecessary ports)
- Adding alarms (detect break-ins)
- Using strong locks (encryption)
- Limiting access (least privilege)

This guide covers what hardening does and how to apply it.

---

## What Gets Hardened

The deployment includes automatic hardening of:
1. **Operating System** (Linux/Ubuntu)
2. **Network** (firewall, ports)
3. **Authentication** (SSH, passwords)
4. **Application** (dependencies, permissions)
5. **Monitoring** (detect threats)

---

## Automatic Hardening (During Deployment)

The `setup.yml` playbook automatically applies hardening. You get:

### ✅ SSH Security
- **SSH Keys Only** - No password login (more secure)
- **Key Rotation** - Use strong RSA keys
- **Limited SSH Users** - Only `ubuntu` user (main), then app runs as unprivileged user
- **SSH Port** - Open on port 22 (standard)
- **Root Login Disabled** - Can't SSH as root

### ✅ Network Security
- **Firewall (UFW)** - Only allow ports 22, 80, 443
- **Port Scanning** - Configured to fail closed
- **IPv6** - Disabled on unused interfaces

### ✅ File Permissions
- **Application Files** - Owned by app user, not root
- **Configuration Files** - Restricted permissions (600/700)
- **Secret Files** - Encryption at rest, restricted access
- **Logs** - Readable only by app or admin

### ✅ User Accounts
- **App User** - Unprivileged, can't login
- **No Default Passwords** - All passwords set to strong values
- **sudo Restrictions** - Limited what app can elevate to
- **User Auditing** - Track who did what

### ✅ System Updates
- **Auto-Updates** - Security patches applied automatically
- **Unattended Upgrades** - OS updates without manual intervention
- **Automatic Restarts** - Server reboots when needed (during low-traffic)

### ✅ Application Security
- **Dependencies** - Pinned versions (no unexpected updates)
- **Gunicorn** - Runs as unprivileged user
- **Systemd** - App auto-restarts if crashed
- **Sandboxing** - Limited file access

### ✅ Logging & Monitoring
- **Syslog** - All events logged
- **Access Logs** - HTTP requests logged
- **Error Logs** - Application errors logged
- **Audit Trail** - Track all changes

### ✅ SSL/HTTPS
- **Let's Encrypt** - Free, automated certificates
- **Auto-Renewal** - Certificates auto-renew before expiry
- **TLS 1.2+** - Modern encryption only
- **Strong Ciphers** - No weak encryption

---

## Running Hardening Playbook

If you need to reapply hardening or run it separately:

```bash
cd deployment

# Apply security hardening
ansible-playbook -i inventories playbooks/security-hardening.yml
```

**What it does:**
- ✅ Configures firewall (UFW)
- ✅ Hardens SSH settings
- ✅ Sets file permissions
- ✅ Enables automatic updates
- ✅ Configures audit logging
- ✅ Hardens kernel parameters
- ✅ Enables fail2ban (intrusion detection)

**Duration:** 3-5 minutes

---

## Verifying Hardening

### Check SSH Security

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check SSH config
sudo sshd -T | grep -E "passwordauth|pubkeyauth|permitrootlogin|port"

# Expected output:
# passwordauthentication no          ✅ (no password allowed)
# pubkeyauthentication yes           ✅ (keys only)
# permitrootlogin no                 ✅ (root can't login)
# port 22                            ✅ (standard port)

exit
```

### Check Firewall

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check firewall status
sudo ufw status numbered

# Expected output:
# Status: active
# 
#      To                         Action      From
#      --                         ------      ----
# [ 1] 22/tcp                     ALLOW IN    Anywhere
# [ 2] 80/tcp                     ALLOW IN    Anywhere
# [ 3] 443/tcp                    ALLOW IN    Anywhere
# [ 4] 22/tcp (v6)                ALLOW IN    Anywhere (v6)
# [ 5] 80/tcp (v6)                ALLOW IN    Anywhere (v6)
# [ 6] 443/tcp (v6)               ALLOW IN    Anywhere (v6)

exit
```

### Check File Permissions

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check app directory ownership
ls -la /home/ubuntu/{app_name} | head -3

# Expected: owned by ubuntu:ubuntu or {app_username}:{app_username}

# Check config file permissions
ls -la /home/ubuntu/{app_name}/.env 2>/dev/null || echo "Encrypted or not visible"

# Check log directory
ls -la /var/log/{app_name}/

# Expected: owned by {app_username}:{app_username}

exit
```

### Check Automatic Updates

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check auto-update configuration
cat /etc/apt/apt.conf.d/50unattended-upgrades | grep -E "Unattended-Upgrade::Automatic-Reboot"

# Expected: Unattended-Upgrade::Automatic-Reboot "true"

# Check update logs
sudo tail -20 /var/log/unattended-upgrades/unattended-upgrades.log

exit
```

### Check Fail2Ban (Intrusion Detection)

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check if fail2ban is running
sudo systemctl status fail2ban

# Expected: active (running)

# Check banned IPs
sudo fail2ban-client status sshd

# Expected output shows how many IPs are banned from SSH

# Check all jails
sudo fail2ban-client status

exit
```

---

## Common Hardening Scenarios

### Unblock an IP That Got Blocked by Fail2Ban

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Find the IP in banned list
sudo fail2ban-client status sshd

# Unban the IP (replace X.X.X.X with actual IP)
sudo fail2ban-client set sshd unbanip X.X.X.X

# Verify it's unbanned
sudo fail2ban-client status sshd

exit
```

### Add Another User to SSH

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Add new user
sudo useradd -m -s /bin/bash newuser

# Set password (they change on first login)
sudo passwd newuser

# Create .ssh directory
sudo mkdir -p /home/newuser/.ssh
sudo chmod 700 /home/newuser/.ssh

# Add their public key
echo "ssh-rsa AAAA..." | sudo tee /home/newuser/.ssh/authorized_keys
sudo chmod 600 /home/newuser/.ssh/authorized_keys
sudo chown -R newuser:newuser /home/newuser/.ssh

# Test login
# From another machine: ssh newuser@YOUR_SERVER_IP

exit
```

### Disable Automatic Reboots (Not Recommended)

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Edit unattended upgrades config
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# Find line: Unattended-Upgrade::Automatic-Reboot "true"
# Change to: Unattended-Upgrade::Automatic-Reboot "false"

# Save (Ctrl+X, Y, Enter)

# But then you need to manually reboot after updates!
# Don't forget or you'll be vulnerable

exit
```

### Check What Automatic Updates Did

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check update log
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -50

# Check package history
apt history

# Check installed packages
apt list --installed | grep -i security

exit
```

---

## Hardening Checklist

**After deployment, verify hardening:**

```
SSH Security:
  [ ] SSH keys required (no passwords)
  [ ] Root login disabled
  [ ] Key-based auth working

Firewall:
  [ ] UFW enabled
  [ ] Only ports 22, 80, 443 open
  [ ] Can SSH in
  [ ] HTTP/HTTPS working

File Permissions:
  [ ] App files owned by app user
  [ ] Config files restricted (600)
  [ ] Logs owned by correct user

User Management:
  [ ] App runs as unprivileged user
  [ ] Only admin users have sudo
  [ ] No shared passwords

Updates:
  [ ] Automatic updates enabled
  [ ] Recent security patches applied
  [ ] Server reboots during low-traffic

Monitoring:
  [ ] Logs being collected
  [ ] Fail2ban running
  [ ] CloudWatch monitoring enabled

SSL/HTTPS:
  [ ] Certificate installed
  [ ] HTTPS working
  [ ] Auto-renewal configured
```

---

## Security Best Practices

### Daily

- ✅ Check error logs for unusual patterns
- ✅ Monitor CloudWatch alarms
- ✅ Review access logs for suspicious IPs

### Weekly

- ✅ Check automatic updates were applied
- ✅ Review fail2ban bans (legitimate?)
- ✅ Check disk space (logs growing?)
- ✅ Verify backups completed

### Monthly

- ✅ Review user accounts (remove unused)
- ✅ Check SSH keys (revoke compromised)
- ✅ Test recovery/rollback procedures
- ✅ Review security logs
- ✅ Update WAF rules if needed

### Quarterly

- ✅ Security audit
- ✅ Penetration testing (optional)
- ✅ Review architecture for weaknesses
- ✅ Update hardening procedures

### Annually

- ✅ Full security assessment
- ✅ Compliance audit (if needed)
- ✅ Update security policies
- ✅ Team security training

---

## If You Get Attacked

**DDoS Attack (many requests from one IP):**

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check if server is overwhelmed
top
# Look at load average

# Check network traffic
sudo netstat -an | grep ESTABLISHED | wc -l

# Find attacking IP
sudo netstat -an | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head

# Block the IP
sudo ufw deny from ATTACKER_IP

# Or block a subnet if it's a coordinated attack
sudo ufw deny from ATTACKER_SUBNET

exit
```

**Brute Force Attack (many failed logins):**

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check fail2ban is catching it
sudo fail2ban-client status sshd

# Should show IPs being banned automatically

# If not banned, manually ban
sudo fail2ban-client set sshd banip ATTACKER_IP

exit
```

**Application Attack (many 400/500 errors):**

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Check what's being attacked
sudo tail -100 /var/log/{app_name}/nginx_access.log | grep -E "4[0-9]{2}|5[0-9]{2}"

# See pattern of requests
sudo awk '{print $7}' /var/log/{app_name}/nginx_access.log | sort | uniq -c | sort -rn | head -10

# Block the IP
sudo ufw deny from ATTACKER_IP

# Check if application is still running
sudo systemctl status {app_name}

exit
```

---

## Advanced Security (Optional)

### WAF (Web Application Firewall)

Use AWS WAF to block attacks at the edge:

```bash
cd deployment

# Setup WAF
ansible-playbook playbooks/setup-waf.yml
```

See: [WAF_CONFIGURATION.md](WAF_CONFIGURATION.md) (to be created)

### Intrusion Detection (IDS)

Monitor for attacks in real-time:

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP

# Install Suricata (example IDS)
sudo apt install -y suricata

# Check alerts
sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'

exit
```

### VPN/Bastion Host

For extra security, restrict SSH to VPN only or bastion host (advanced setup).

---

## Security Testing

### Self-Audit

```bash
# Run security scan from local machine
nmap -A YOUR_SERVER_IP

# Expected: Only ports 22, 80, 443 open, all others filtered

# Test SSL strength
nmap --script ssl-cert,ssl-enum-ciphers -p 443 YOUR_SERVER_IP

# Expected: Only TLS 1.2+ with strong ciphers
```

### Tools for Monitoring

- **CloudWatch** - AWS native monitoring
- **fail2ban** - Automatic IP blocking
- **auditd** - Kernel-level audit
- **osquery** - System monitoring
- **Wazuh** - SIEM (advanced)

---

## Next Steps

- **WAF Setup:** [WAF_CONFIGURATION.md](WAF_CONFIGURATION.md) (coming soon)
- **Operations:** [OPERATIONS.md](OPERATIONS.md)
- **Incident Response:** See OPERATIONS.md for attack response procedures
- **Compliance:** If needed, implement CIS benchmarks

---

## Summary

**You now have:**
- ✅ SSH key-based auth (no passwords)
- ✅ Firewall (UFW) with minimal open ports
- ✅ Automatic security updates
- ✅ User-level file permissions
- ✅ Intrusion detection (fail2ban)
- ✅ Automatic certificate renewal
- ✅ Audit logging
- ✅ Monitoring integration

**Your server is hardened against:**
- ❌ Brute force SSH attacks
- ❌ Port scanning exploitation
- ❌ Unpatched vulnerabilities
- ❌ Unauthorized file access
- ❌ Expired certificates
- ❌ Many common attacks

**Not protected against:**
- Application-level attacks (SQL injection, XSS) - app code must handle
- DDoS attacks - need WAF or DDoS protection service
- 0-day exploits - will patch automatically when available
- Social engineering - user training required

**Stay secure!** 🔒

