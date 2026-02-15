# Deployment Guide

**Last Updated:** February 14, 2026

---

## What Do You Want to Do?

### 🚀 I Want to Deploy This App

**Choose your deployment method:**

| Method | Time | Skill Level | Link |
|--------|------|-------------|------|
| **Automated** | 15-20 min | Beginner | → [AUTOMATED_DEPLOYMENT.md](AUTOMATED_DEPLOYMENT.md) |
| **Manual** | 1-2 hours | Intermediate | → [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) |
| **Local Dev** | 5 min | Any | → [../README.md](../README.md#quick-local-setup) |

**Not sure which?** Choose **Automated** - it's easier and faster.

---

### ⚙️ I Already Have It Running

**Common tasks:**

| What You Need | Where to Go |
|---------------|-------------|
| Update code, restart app | [OPERATIONS.md](OPERATIONS.md) |
| Add users, manage accounts | [MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md) |
| Rotate secrets/credentials | [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md) |
| View logs, troubleshoot | [OPERATIONS.md#troubleshooting](OPERATIONS.md#troubleshooting) |
| Understand security | [SECURITY_HARDENING.md](SECURITY_HARDENING.md) |

---

## Prerequisites Summary

**Before deploying, you'll need:**

- ✅ AWS Account (with admin access)
- ✅ AWS CLI installed and configured
- ✅ Python 3.8+ and Ansible
- ✅ GitHub repository with your code

**Managing multiple AWS accounts or regions?** → [AWS_PROFILES_GUIDE.md](AWS_PROFILES_GUIDE.md)

**Don't have these?** Each deployment guide has detailed prerequisites section.

---

## Documentation Structure

| File | Purpose |
|------|---------|
| **README.md** ← You are here | Roadmap - choose what you want to do |
| **[AUTOMATED_DEPLOYMENT.md](AUTOMATED_DEPLOYMENT.md)** | One-command automated setup |
| **[MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md)** | Step-by-step manual deployment |
| **[PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)** | Verify you're ready (used by guides) |
| **[OPERATIONS.md](OPERATIONS.md)** | Daily operations after deployment |
| **[SECURITY_HARDENING.md](SECURITY_HARDENING.md)** | Security architecture details |
| **[MULTI_USER_SUPPORT.md](MULTI_USER_SUPPORT.md)** | Multi-user feature guide |
| **[SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)** | Managing credentials |

---

## Quick Reference

### Common Commands

```bash
# Deploy
./scripts/infra-complete-setup.sh        # Automated deployment
ansible-playbook -i inventories/production playbooks/setup.yml  # Manual deployment

# Manage
sudo systemctl status {app_name}         # Check status
sudo systemctl restart {app_name}        # Restart
sudo journalctl -u {app_name} -f         # View logs

# Update
ansible-playbook -i inventories/production playbooks/update.yml
```

### Cost Estimate

- **Free tier:** ~$2/month (first year)
- **After free tier:** ~$10-15/month (t3.micro + S3)

---

## Architecture Overview

```
User → Nginx (HTTPS) → Gunicorn (Flask App) → CSV Files + AWS S3
```

**Components:**
- Nginx: Web server, SSL, reverse proxy
- Gunicorn: WSGI server (4 workers)
- Flask: Your application
- CSV: Local inventory storage
- S3: Cloud image storage

**Security:**
- Dedicated app user (no SSH)
- 20+ systemd hardening features
- Firewall configured
- IAM roles (no credentials on disk)

**Full details:** → [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## Need Help?

1. **Deployment issues:** Check the deployment guide you're using
2. **After deployment:** See [OPERATIONS.md](OPERATIONS.md)
3. **Other questions:** [GitHub Issues](../../issues)

---

<div align="center">

**Ready to deploy?** Choose [Automated](AUTOMATED_DEPLOYMENT.md) or [Manual](MANUAL_DEPLOYMENT.md) above ⬆️

</div>

