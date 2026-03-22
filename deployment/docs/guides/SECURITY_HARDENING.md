# Chapter 8: Security Hardening

Verify, tune, and maintain the security controls applied automatically during deployment.

---

## Overview

Security hardening reduces the attack surface of your server by closing unnecessary ports, enforcing strong authentication, encrypting data, and applying the principle of least privilege.

All hardening is applied automatically during deployment:
- **`setup-server.yml`** applies OS-level hardening: SSH lockdown, fail2ban, automatic security updates, sysctl kernel protections, disabled unused services, and system logging.
- **`setup.yml`** applies application-level hardening: file permissions, SSL certificates, Nginx security headers, and rate limiting.

This chapter covers how to verify, tune, and maintain those controls.

---

## What Gets Hardened (Automatically)

### SSH Security (setup-server.yml)

| Setting | Value | Config file |
|---------|-------|-------------|
| Password authentication | Disabled | `/etc/ssh/sshd_config` |
| Root login | Disabled | `/etc/ssh/sshd_config` |
| Max auth tries | 3 | `/etc/ssh/sshd_config` |
| Allowed users | `ubuntu` only (key-based) | SSH authorized_keys |

### Kernel Protections — sysctl (setup-server.yml)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `net.ipv4.conf.all.rp_filter` | 1 | IP spoofing protection |
| `net.ipv4.conf.default.rp_filter` | 1 | IP spoofing protection |
| `net.ipv4.icmp_echo_ignore_broadcasts` | 1 | Ignore ICMP broadcast requests |
| `net.ipv4.conf.all.accept_source_route` | 0 | Disable source routing |
| `net.ipv6.conf.all.accept_source_route` | 0 | Disable source routing (IPv6) |
| `net.ipv4.conf.default.accept_source_route` | 0 | Disable source routing |
| `net.ipv6.conf.default.accept_source_route` | 0 | Disable source routing (IPv6) |
| `net.ipv4.conf.all.send_redirects` | 0 | Ignore ICMP redirects |
| `net.ipv4.conf.default.send_redirects` | 0 | Ignore ICMP redirects |
| `net.ipv4.tcp_syncookies` | 1 | SYN flood protection |
| `net.ipv4.tcp_max_syn_backlog` | 2048 | SYN flood protection |
| `net.ipv4.tcp_synack_retries` | 2 | SYN flood protection |
| `net.ipv4.tcp_syn_retries` | 5 | SYN flood protection |
| `net.ipv4.conf.all.log_martians` | 1 | Log spoofed packets |
| `net.ipv4.conf.default.log_martians` | 1 | Log spoofed packets |

### Automatic Security Updates (setup-server.yml)

| Setting | Value | Config file |
|---------|-------|-------------|
| Security patches | Auto-installed daily | `/etc/apt/apt.conf.d/50unattended-upgrades` |
| Update check frequency | Daily | `/etc/apt/apt.conf.d/20auto-upgrades` |
| Automatic reboot | Disabled (manual) | `50unattended-upgrades` |
| Reboot time (if enabled) | 03:00 UTC | `50unattended-upgrades` |
| Unused kernel cleanup | Enabled | `50unattended-upgrades` |

### Fail2Ban — Brute Force Protection (setup-server.yml)

| Jail | Max retries | Find time | Ban time | Log file |
|------|-------------|-----------|----------|----------|
| `sshd` | 3 | 20 min | 24 hours | `/var/log/auth.log` |
| `nginx-http-auth` | 3 | 10 min | 10 min | `/var/log/nginx/*error.log` |
| `nginx-noscript` | 3 | 10 min | 10 min | `/var/log/nginx/*access.log` |
| `nginx-badbots` | 1 | 10 min | 24 hours | `/var/log/nginx/*access.log` |
| `nginx-botsearch` | 3 | 10 min | 10 min | `/var/log/nginx/*access.log` |
| `nginx-limit-req` | 2 | 10 min | 24 hours | `/var/log/nginx/*error.log` |
| `nginx-404` | 20 | 2 min | 1 hour | `/var/log/nginx/*access.log` |
| `nginx-403` | 10 | 2 min | 1 hour | `/var/log/nginx/*access.log` |
| `recidive` | 3 | 24 hours | 7 days | `/var/log/fail2ban.log` |

### Disabled Services (setup-server.yml)

These services are stopped and disabled if present: `apache2`, `avahi-daemon`, `cups`, `bluetooth`.

### File Permissions (setup.yml, update.yml)

| Path | Owner | Group | Mode | Purpose |
|------|-------|-------|------|---------|
| `/opt/{app_name}/` | `{app_user}` | `{app_name}` | `2775` (setgid) | App directory |
| `/opt/{app_name}/instance/` | `{app_user}` | `{app_name}` | `2775` (setgid) | Data directory |
| `/opt/{app_name}/logs/` | `{app_user}` | `{app_name}` | `2775` (setgid) | Log directory |
| `instance/user_preferences.json` | `{app_user}` | `{app_name}` | `0640` | User credentials |
| `instance/*.csv`, `instance/sku.txt` | `{app_user}` | `{app_name}` | `0664` | Data files |
| `app/static/` | `{app_user}` | `{app_name}` | `2775` (recurse) | Static assets |
| `app/scripts/` | `{app_user}` | `{app_name}` | `2775` (recurse) | Utility scripts |
| Log files (`*.log`) | `{app_user}` | `{app_name}` | `0664` | Not executable |
| `~/.ssh/authorized_keys` | `{admin_user}` | `{admin_user}` | `0600` | SSH keys |

The `{app_name}` group contains both `{admin_user}` (deploy) and `{app_user}` (runtime). Setgid on directories ensures new files inherit the group.

### SSL/HTTPS (setup.yml)

| Setting | Value |
|---------|-------|
| Certificate provider | Let's Encrypt (certbot) |
| Auto-renewal | Daily cron + systemd timer |
| TLS version | 1.2+ (Let's Encrypt defaults) |
| HSTS | 1 year, includeSubDomains |
| HTTP redirect | 301 to HTTPS |
| OCSP stapling | Enabled |

### Nginx Security Headers (setup.yml)

| Header | Value |
|--------|-------|
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-Content-Type-Options` | `nosniff` |
| `X-XSS-Protection` | `1; mode=block` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` |
| `Content-Security-Policy` | Restrictive policy allowing self, S3, eBay images |
| `server_tokens` | `off` (hides Nginx version) |

### Shared Memory (setup-server.yml)

`/run/shm` is mounted with `noexec,nosuid` to prevent execution of malicious code from shared memory.

---

## Verifying Hardening

### Check SSH Security

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Check SSH config
sudo sshd -T | grep -E "passwordauth|pubkeyauth|permitrootlogin|maxauthtries"

# Expected output:
# passwordauthentication no
# pubkeyauthentication yes
# permitrootlogin no
# maxauthtries 3

exit
```

### Check Fail2Ban

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Check fail2ban is running
sudo systemctl status fail2ban

# List all jails
sudo fail2ban-client status

# Check SSH jail specifically
sudo fail2ban-client status sshd

# Check nginx jails
sudo fail2ban-client status nginx-limit-req
sudo fail2ban-client status nginx-404

# View recent bans
sudo tail -50 /var/log/fail2ban.log

exit
```

### Check Automatic Updates

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Check unattended-upgrades config
cat /etc/apt/apt.conf.d/50unattended-upgrades | grep -E "Allowed-Origins|Automatic-Reboot"

# Check auto-upgrades is enabled
cat /etc/apt/apt.conf.d/20auto-upgrades

# Check recent update activity
sudo tail -30 /var/log/unattended-upgrades/unattended-upgrades.log

# Check if updates are pending
apt list --upgradable 2>/dev/null

exit
```

### Check Sysctl Settings

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Verify all sysctl settings
sysctl net.ipv4.conf.all.rp_filter             # Expected: 1
sysctl net.ipv4.icmp_echo_ignore_broadcasts     # Expected: 1
sysctl net.ipv4.conf.all.accept_source_route    # Expected: 0
sysctl net.ipv4.conf.all.send_redirects         # Expected: 0
sysctl net.ipv4.tcp_syncookies                  # Expected: 1
sysctl net.ipv4.tcp_max_syn_backlog             # Expected: 2048
sysctl net.ipv4.conf.all.log_martians           # Expected: 1

exit
```

### Check SSL Certificate

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Check certificate exists
sudo certbot certificates

# Check certificate expiry
sudo openssl x509 -in /etc/letsencrypt/live/{server_name}/fullchain.pem -noout -dates

# Check renewal timer
sudo systemctl status certbot.timer

# Test renewal (dry run)
sudo certbot renew --dry-run

exit
```

### Check File Permissions

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Check app directory ownership and setgid
ls -la /opt/{app_name}/ | head -5
# Expected: drwxrwsr-x  owner:group = {app_user}:{app_name}
# The 's' in group-execute confirms setgid is set.

# Check log directory
ls -la /opt/{app_name}/logs/
# Expected: drwxrwsr-x  owner:group = {app_user}:{app_name}

# Verify both users are in the shared group
getent group {app_name}
# Expected: {app_name}:x:NNN:ubuntu,{app_user}

exit
```

### Check Nginx Security Headers

```bash
# From your local machine
curl -sI https://{server_name} | grep -iE "x-frame|x-content|x-xss|strict-transport|referrer|permissions|content-security"
```

### Check Disabled Services

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Verify these are not running
systemctl is-active apache2 2>/dev/null || echo "apache2: not active (correct)"
systemctl is-active avahi-daemon 2>/dev/null || echo "avahi-daemon: not active (correct)"
systemctl is-active cups 2>/dev/null || echo "cups: not active (correct)"

exit
```

### Check Shared Memory

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

grep "/run/shm" /etc/fstab
# Expected: tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0

mount | grep shm
# Should show noexec,nosuid options

exit
```

---

## Tuning Hardening Settings

### Adjust Fail2Ban Ban Times

Edit `deployment/templates/jail.local.j2` and redeploy, or edit directly on the server:

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Edit fail2ban config
sudo nano /etc/fail2ban/jail.local

# Key settings to tune:
# [DEFAULT]
# bantime = 86400      # Ban duration in seconds (86400 = 24 hours)
# findtime = 1200      # Time window for counting failures (1200 = 20 min)
# maxretry = 3         # Failures before ban
#
# Per-jail overrides:
# [nginx-404]
# maxretry = 20        # Allow 20 404s before banning (increase if needed)
# findtime = 120       # Within 2 minutes
# bantime = 3600       # Ban for 1 hour

# Restart fail2ban after changes
sudo systemctl restart fail2ban

exit
```

### Adjust Automatic Update Settings

Edit `deployment/templates/50unattended-upgrades.j2` and redeploy, or edit directly:

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# Enable automatic reboot after kernel updates:
# Unattended-Upgrade::Automatic-Reboot "true";
# Unattended-Upgrade::Automatic-Reboot-Time "03:00";

# Blacklist specific packages from auto-update:
# Unattended-Upgrade::Package-Blacklist {
#     "nginx";
# };

# Enable email notifications:
# Unattended-Upgrade::Mail "your-email@example.com";
# Unattended-Upgrade::MailReport "on-change";

exit
```

### Adjust SSH Settings

Edit `deployment/playbooks/setup-server.yml` SSH block and redeploy, or edit directly:

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

sudo nano /etc/ssh/sshd_config

# Change max auth tries:
# MaxAuthTries 5          # Increase from 3 if you have many keys

# Restrict SSH to specific users:
# AllowUsers ubuntu

# Change idle timeout:
# ClientAliveInterval 300
# ClientAliveCountMax 2

# Apply changes
sudo systemctl restart sshd

exit
```

### Adjust Sysctl Parameters

Edit `deployment/playbooks/setup-server.yml` sysctl block and redeploy, or change directly:

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# View current value
sysctl net.ipv4.tcp_max_syn_backlog

# Change a value temporarily (resets on reboot)
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=4096

# Change permanently
echo "net.ipv4.tcp_max_syn_backlog = 4096" | sudo tee -a /etc/sysctl.d/99-custom.conf
sudo sysctl -p /etc/sysctl.d/99-custom.conf

exit
```

### Adjust Nginx Security Headers

Edit `deployment/templates/nginx.conf.j2` and redeploy:

```bash
cd deployment
ansible-playbook playbooks/update.yml --vault-password-file ~/.vault_pass
```

Common adjustments:
- **Content-Security-Policy**: Add domains for third-party scripts or images
- **HSTS max-age**: Reduce during testing, increase for production
- **X-Frame-Options**: Change to `DENY` if no iframes needed

### Adjust Nginx Rate Limits

Rate limits are defined at the top of `deployment/templates/nginx.conf.j2`:

| Zone | Default rate | Purpose |
|------|-------------|---------|
| `login_limit` | 20 req/min | Login endpoint |
| `api_limit` | 200 req/min | API endpoints |
| `general_limit` | 300 req/min | General pages |

To change, edit the template and redeploy. Each zone also has a `burst` setting on individual `location` blocks that allows brief spikes above the rate.

---

## Re-applying Hardening

To re-apply all hardening settings (useful after manual changes or server drift):

```bash
cd deployment

# Re-apply OS-level hardening (SSH, fail2ban, sysctl, auto-updates)
ansible-playbook playbooks/security-hardening.yml --vault-password-file ~/.vault_pass

# Re-apply file permissions and nginx config
ansible-playbook playbooks/update.yml --vault-password-file ~/.vault_pass
```

The `security-hardening.yml` playbook applies the same tasks as the `setup-server.yml` hardening section. It is safe to run repeatedly — all tasks are idempotent.

---

## Common Scenarios

### Unblock an IP Banned by Fail2Ban

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Find banned IPs
sudo fail2ban-client status sshd

# Unban a specific IP
sudo fail2ban-client set sshd unbanip X.X.X.X

# Check nginx jails too
sudo fail2ban-client status nginx-limit-req
sudo fail2ban-client set nginx-limit-req unbanip X.X.X.X

exit
```

### Whitelist an IP in Fail2Ban

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

sudo nano /etc/fail2ban/jail.local

# Add to [DEFAULT] section:
# ignoreip = 127.0.0.1/8 ::1 YOUR_IP_HERE

sudo systemctl restart fail2ban

exit
```

### Force SSL Certificate Renewal

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Check current certificate expiry
sudo certbot certificates

# Force renewal
sudo certbot renew --force-renewal

# Reload nginx
sudo systemctl reload nginx

exit
```

### Check What Automatic Updates Installed

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# View unattended-upgrades log
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -50

# View apt history
cat /var/log/apt/history.log | tail -50

# Check if reboot is required after updates
cat /var/run/reboot-required 2>/dev/null || echo "No reboot required"

exit
```

### Add Another SSH User

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER

# Create user
sudo useradd -m -s /bin/bash newuser

# Setup SSH key auth (no passwords allowed)
sudo mkdir -p /home/newuser/.ssh
sudo chmod 700 /home/newuser/.ssh
echo "ssh-rsa AAAA..." | sudo tee /home/newuser/.ssh/authorized_keys
sudo chmod 600 /home/newuser/.ssh/authorized_keys
sudo chown -R newuser:newuser /home/newuser/.ssh

exit
```

---

## Security Testing

### Port Scan

```bash
# From your local machine
nmap -A {server_name}

# Expected: Only ports 22, 80, 443 open
# Port 80 should redirect to 443
```

### SSL Strength

```bash
# Test SSL configuration
nmap --script ssl-cert,ssl-enum-ciphers -p 443 {server_name}

# Expected: TLS 1.2+ with strong ciphers only

# Or use SSL Labs (free online test):
# https://www.ssllabs.com/ssltest/analyze.html?d={server_name}
```

### Security Headers

```bash
# Test all headers at once
curl -sI https://{server_name} | head -20

# Or use securityheaders.com:
# https://securityheaders.com/?q=https://{server_name}
```

---

## Security Maintenance Schedule

### Weekly

- Check fail2ban bans for false positives: `sudo fail2ban-client status`
- Review nginx error logs for attack patterns
- Verify automatic updates ran: check `/var/log/unattended-upgrades/`
- Check disk space (logs growing): `df -h`

### Monthly

- Review user accounts: `cat /etc/passwd | grep -v nologin`
- Check SSH authorized_keys for unexpected entries
- Verify SSL certificate expiry: `sudo certbot certificates`
- Review fail2ban jail thresholds

### Quarterly

- Run `nmap` port scan against your server
- Test SSL strength with SSL Labs
- Review and update Nginx security headers
- Check for new sysctl recommendations

---

## Summary

All security hardening is applied automatically during deployment:

| Control | Applied by | Re-apply with |
|---------|-----------|---------------|
| SSH lockdown | `setup-server.yml` | `security-hardening.yml` |
| Fail2ban | `setup-server.yml` | `security-hardening.yml` |
| Auto-updates | `setup-server.yml` | `security-hardening.yml` |
| Sysctl protections | `setup-server.yml` | `security-hardening.yml` |
| Service disabling | `setup-server.yml` | `security-hardening.yml` |
| System logging | `setup-server.yml` | `security-hardening.yml` |
| File permissions | `setup.yml` / `update.yml` | `update.yml` or `harden-permissions.yml` |
| SSL certificate | `setup.yml` | `setup-ssl.yml` |
| Nginx headers | `setup.yml` / `update.yml` | `update.yml` |
| Rate limiting | `setup.yml` / `update.yml` | `update.yml` |

---

## Next step

Continue to [Chapter 9: Multi-User Support](MULTI_USER.md).

## See also

- [Chapter 11: WAF Configuration](WAF_CONFIGURATION.md) — block attacks at the edge
- [User Isolation Model](../reference/SECURITY.md) — two-user privilege model
- [Application Security](../reference/APPLICATION_SECURITY.md) — WAF rules, attack detection, rate limiting
