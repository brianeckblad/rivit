# Chapter 8: Security Hardening
anVerify, tune, and maintain the security controls for this application on a shared server.

---

## Overview

Security hardening is split into two layers with different scopes and ownership.

| Layer | Scope | Applied by | Who runs it |
|-------|-------|------------|-------------|
| **App-level** | This app only — file permissions, SSL cert, nginx vhost, rate limiting | `setup.yml`, `update.yml`, `harden-permissions.yml` | App deployer (you) |
| **Server-level** | Entire shared server — SSH config, sysctl, fail2ban, auto-updates | `security-hardening.yml` | Server admin |

**App deployers should only run app-level playbooks.** Server-level changes (SSH lockdown, sysctl, fail2ban, apt upgrades) affect every application on the server and must be coordinated with the server admin.

---

## App-Level Hardening (Your Responsibility)

These settings are applied automatically by `setup.yml` and re-applied on every `update.yml` run.

### File Permissions

| Path | Owner | Group | Mode | Purpose |
|------|-------|-------|------|---------|
| `/opt/{app_name}/` | `{app_user}` | `{app_name}` | `2775` (setgid) | App directory |
| `/opt/{app_name}/instance/` | `{app_user}` | `{app_name}` | `2775` (setgid) | Data directory |
| `/var/log/{app_name}/` | `{app_user}` | `{app_name}` | `2775` (setgid) | Log directory |
| `instance/user_preferences.json` | `{app_user}` | `{app_name}` | `0640` | User credentials |
| `instance/*.csv`, `instance/sku.txt` | `{app_user}` | `{app_name}` | `0664` | Data files |
| `app/static/` | `{app_user}` | `{app_name}` | `2775` (recurse) | Static assets |
| `app/scripts/` | `{app_user}` | `{app_name}` | `2775` (recurse) | Utility scripts |
| Log files (`*.log`) | `{app_user}` | `{app_name}` | `0664` | Not executable |
| `~/.ssh/authorized_keys` | `{admin_user}` | `{admin_user}` | `0600` | SSH keys |

The `{app_name}` group contains both `{admin_user}` (deploy) and `{app_user}` (runtime). Setgid on directories ensures new files inherit the group automatically.

To re-apply permissions without redeploying code:

```bash
cd deployment
ansible-playbook playbooks/harden-permissions.yml --vault-password-file ~/.vault_pass
```

### SSL/HTTPS

| Setting | Value |
|---------|-------|
| Certificate provider | Let's Encrypt (certbot) |
| Auto-renewal | Daily cron + systemd timer |
| TLS version | 1.2+ (Let's Encrypt defaults) |
| HSTS | 1 year, includeSubDomains |
| HTTP redirect | 301 to HTTPS |
| OCSP stapling | Enabled |

### Nginx Security Headers (per-vhost)

| Header | Value |
|--------|-------|
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-Content-Type-Options` | `nosniff` |
| `X-XSS-Protection` | `1; mode=block` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` |
| `Content-Security-Policy` | Restrictive policy allowing self, S3, eBay images |
| `server_tokens` | `off` (hides Nginx version) |

### Nginx Rate Limits (per-vhost)

| Zone | Default rate | Purpose |
|------|-------------|---------|
| `login_limit` | 20 req/min | Login endpoint |
| `api_limit` | 200 req/min | API endpoints |
| `general_limit` | 300 req/min | General pages |

To update headers or rate limits, edit `deployment/templates/nginx.conf.j2` and redeploy:

```bash
cd deployment
ansible-playbook playbooks/update.yml --vault-password-file ~/.vault_pass
```

---

## Verifying App-Level Hardening

### Check file permissions

```bash
ssh ubuntu@YOUR_SERVER

# App directory ownership and setgid
ls -la /opt/{app_name}/
# Expected: drwxrwsr-x  owner:group = {app_user}:{app_name}
# The 's' in group-execute confirms setgid is set.

# Log directory
ls -la /var/log/{app_name}/

# Both users are in the shared group
getent group {app_name}
# Expected: {app_name}:x:NNN:ubuntu,{app_user}
```

### Check SSL certificate

```bash
ssh ubuntu@YOUR_SERVER

# Certificate exists
sudo certbot certificates

# Expiry date
sudo openssl x509 -in /etc/letsencrypt/live/{server_name}/fullchain.pem -noout -dates

# Renewal timer running
sudo systemctl status certbot.timer

# Dry-run renewal
sudo certbot renew --dry-run
```

### Check nginx security headers

```bash
# From your local machine
curl -sI https://{server_name} | grep -iE "x-frame|x-content|x-xss|strict-transport|referrer|permissions|content-security"
```

### Check application is running as unprivileged user

```bash
ssh ubuntu@YOUR_SERVER

# Process should be owned by {app_user}, not root
ps aux | grep gunicorn
# Expected: {app_user}    ...  gunicorn...
```

---

## SSL Operations

### Force SSL certificate renewal

```bash
ssh ubuntu@YOUR_SERVER

# Check current expiry
sudo certbot certificates

# Force renewal
sudo certbot renew --force-renewal

# Reload nginx (graceful, no downtime)
sudo systemctl reload nginx
```

### Obtain SSL certificate if it failed during setup

```bash
cd deployment
ansible-playbook playbooks/setup-ssl.yml --vault-password-file ~/.vault_pass
```

---

## Server-Level Hardening (Coordinate with Server Admin)

> **Do not run `security-hardening.yml` without coordinating with the server admin.** It runs `apt dist-upgrade`, modifies SSH config, sysctl, fail2ban, and `/etc/fstab` — changes that affect all applications on the server.

These OS-level controls should be applied to the shared server once, by the server admin. If you are the server admin and you own this server, the playbook is available:

```bash
cd deployment

# Requires explicit confirmation flag — will fail without it
ansible-playbook playbooks/security-hardening.yml \
    --vault-password-file ~/.vault_pass \
    -e server_hardening_confirmed=true
```

### What server-level hardening covers

| Control | Config file | Purpose |
|---------|-------------|---------|
| SSH: password auth disabled | `/etc/ssh/sshd_config` | Key-only access |
| SSH: root login disabled | `/etc/ssh/sshd_config` | No direct root SSH |
| SSH: MaxAuthTries 3 | `/etc/ssh/sshd_config` | Brute force limit |
| sysctl: IP spoofing protection | `/etc/sysctl.d/` | `rp_filter = 1` |
| sysctl: SYN flood protection | `/etc/sysctl.d/` | `tcp_syncookies = 1` |
| sysctl: source routing disabled | `/etc/sysctl.d/` | Routing attack defense |
| fail2ban: SSH jail | `/etc/fail2ban/jail.local` | 3 attempts, 24h ban |
| fail2ban: nginx jails | `/etc/fail2ban/jail.local` | 404, 403, bad bots |
| Automatic security updates | `/etc/apt/apt.conf.d/` | Daily security patches |
| Disabled services | systemd | apache2, avahi-daemon, cups, bluetooth |
| Shared memory: noexec,nosuid | `/etc/fstab` | Prevent exec from /run/shm |

### Verify server-level hardening

```bash
ssh ubuntu@YOUR_SERVER

# SSH settings
sudo sshd -T | grep -E "passwordauth|pubkeyauth|permitrootlogin|maxauthtries"
# Expected:
#   passwordauthentication no
#   pubkeyauthentication yes
#   permitrootlogin no
#   maxauthtries 3

# fail2ban running
sudo systemctl status fail2ban
sudo fail2ban-client status

# Automatic updates enabled
cat /etc/apt/apt.conf.d/20auto-upgrades

# Shared memory
grep "/run/shm" /etc/fstab

# Sysctl
sysctl net.ipv4.conf.all.rp_filter        # Expected: 1
sysctl net.ipv4.tcp_syncookies            # Expected: 1
sysctl net.ipv4.conf.all.log_martians     # Expected: 1
```

---

## Unblock an IP Banned by Fail2Ban

```bash
ssh ubuntu@YOUR_SERVER

# Find banned IPs
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-limit-req

# Unban a specific IP
sudo fail2ban-client set sshd unbanip X.X.X.X
sudo fail2ban-client set nginx-limit-req unbanip X.X.X.X
```

---

## Security Maintenance Schedule

### Weekly

- Check fail2ban bans for false positives: `sudo fail2ban-client status`
- Review nginx error logs: `sudo tail -50 /var/log/nginx/error.log`
- Verify SSL certificate not expiring soon: `sudo certbot certificates`
- Check disk space (logs growing): `df -h`

### Monthly

- Review user accounts: `getent group {app_name}`
- Verify application is running as `{app_user}`, not root: `ps aux | grep gunicorn`
- Review nginx security headers: `curl -sI https://{server_name}`

### Quarterly

- Port scan: `nmap -A {server_name}` — expected: 22, 80, 443 open
- SSL Labs test: `https://www.ssllabs.com/ssltest/analyze.html?d={server_name}`
- Security headers test: `https://securityheaders.com/?q=https://{server_name}`

---

## Next step

Continue to [Chapter 9: Multi-User Support](MULTI_USER.md).

## See also

- [Chapter 6: Monitoring](MONITORING.md) — CloudWatch dashboards and alarms
