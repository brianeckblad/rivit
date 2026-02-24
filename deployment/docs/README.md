# Deployment Documentation

Complete guides for deploying your application to AWS.

---

## Quick Start (Choose One Path)

### 🚀 **Just Want to Deploy?**
1. Start here: [PREREQUISITES.md](guides/PREREQUISITES.md) - Setup your AWS account and tools
2. Then: [MANUAL_DEPLOYMENT.md](guides/MANUAL_DEPLOYMENT.md) - Step-by-step deployment

### 📚 **Want to Understand How It Works?**
1. Read: [INFRASTRUCTURE.md](guides/INFRASTRUCTURE.md) - Understand each AWS component
2. Then: [EBS_APPLICATION_STORAGE.md](guides/EBS_APPLICATION_STORAGE.md) - How your app stores data
3. Then: [ARCHITECTURE.md](reference/ARCHITECTURE.md) - System design overview

### 🔐 **Security Focused?**
1. Read: [SECURITY.md](reference/SECURITY.md) - Security model overview
2. Then: [SECRET_MANAGEMENT.md](guides/SECRET_MANAGEMENT.md) - Manage sensitive data
3. Then: [SECURITY_HARDENING.md](guides/SECURITY_HARDENING.md) - Harden your server

---

## All Guides

### **Getting Started** (Do These First)
- [PREREQUISITES.md](guides/PREREQUISITES.md) - AWS account, tools, configuration
- [MANUAL_DEPLOYMENT.md](guides/MANUAL_DEPLOYMENT.md) - Deploy step-by-step

### **Understanding the System**
- [INFRASTRUCTURE.md](guides/INFRASTRUCTURE.md) - Each AWS component explained
- [EBS_APPLICATION_STORAGE.md](guides/EBS_APPLICATION_STORAGE.md) - Application storage on EBS
- [ARCHITECTURE.md](reference/ARCHITECTURE.md) - System design

### **Operations & Maintenance**
- [OPERATIONS.md](guides/OPERATIONS.md) - Running and managing your app
- [UPDATING_APPLICATION.md](guides/UPDATING_APPLICATION.md) - Deploy code updates
- [MONITORING.md](guides/MONITORING.md) - Monitor your application

### **Optional Features**
- [MULTI_USER.md](guides/MULTI_USER.md) - Multiple user accounts
- [CLOUDFRONT_CDN.md](guides/CLOUDFRONT_CDN.md) - Content delivery network
- [WAF_CONFIGURATION.md](guides/WAF_CONFIGURATION.md) - Web application firewall

### **Security & Configuration**
- [SECRET_MANAGEMENT.md](guides/SECRET_MANAGEMENT.md) - AWS Secrets Manager strategy
- [SECRETS_MANAGER_SETUP.md](guides/SECRETS_MANAGER_SETUP.md) - Technical guide for setup-secrets-manager.yml playbook
- [SECURITY_HARDENING.md](guides/SECURITY_HARDENING.md) - Security hardening
- [SECURITY.md](reference/SECURITY.md) - Security model overview

### **Reference**
- [USER_MODEL.md](reference/USER_MODEL.md) - User types and permissions

---

## Documentation Structure

```
docs/
├── guides/               ← How-to guides (step-by-step)
│   ├── PREREQUISITES.md
│   ├── MANUAL_DEPLOYMENT.md
│   ├── INFRASTRUCTURE.md
│   ├── EBS_APPLICATION_STORAGE.md
│   ├── OPERATIONS.md
│   ├── UPDATING_APPLICATION.md
│   ├── MONITORING.md
│   ├── SECRET_MANAGEMENT.md
│   ├── SECURITY_HARDENING.md
│   ├── MULTI_USER.md
│   ├── CLOUDFRONT_CDN.md
│   └── WAF_CONFIGURATION.md
│
├── reference/           ← Reference material (design, not how-to)
│   ├── ARCHITECTURE.md
│   ├── SECURITY.md
│   └── USER_MODEL.md
│
└── README.md           ← This file
```

---

## Common Tasks

### Deploy for the First Time
1. [PREREQUISITES.md](guides/PREREQUISITES.md) - Setup (1-2 hours)
2. [MANUAL_DEPLOYMENT.md](guides/MANUAL_DEPLOYMENT.md) - Deploy (30-60 min)
3. [OPERATIONS.md](guides/OPERATIONS.md) - Start using

### Update Application Code
See [UPDATING_APPLICATION.md](guides/UPDATING_APPLICATION.md)

### Monitor Your Application
See [MONITORING.md](guides/MONITORING.md)

### Manage Users
See [MULTI_USER.md](guides/MULTI_USER.md)

### Add Security Features
See [SECURITY_HARDENING.md](guides/SECURITY_HARDENING.md)

### Setup CDN (Optional)
See [CLOUDFRONT_CDN.md](guides/CLOUDFRONT_CDN.md)

### Setup WAF (Optional)
See [WAF_CONFIGURATION.md](guides/WAF_CONFIGURATION.md)

---

## Need Help?

- **Error during deployment?** Check [MANUAL_DEPLOYMENT.md](guides/MANUAL_DEPLOYMENT.md) troubleshooting section
- **AWS question?** Check [INFRASTRUCTURE.md](guides/INFRASTRUCTURE.md)
- **Security question?** Check [SECURITY.md](reference/SECURITY.md) or [SECURITY_HARDENING.md](guides/SECURITY_HARDENING.md)
- **How does the app work?** Check [ARCHITECTURE.md](reference/ARCHITECTURE.md)

---

## Key Concepts

### Application Storage
Your application runs entirely on an **EBS volume** mounted at `/{app_name}`:
- Code, environment, logs, and data all on EBS
- Persists across instance restarts
- Easy backup via EBS snapshots

See [EBS_APPLICATION_STORAGE.md](guides/EBS_APPLICATION_STORAGE.md)

### Two-Tier User Model
- **admin_user**: SSH access, deployment (default: ubuntu)
- **app_user**: Application runtime only, no SSH access

See [USER_MODEL.md](reference/USER_MODEL.md)

### Secrets Management
Sensitive data stored in **AWS Secrets Manager**, not in files.
- Database credentials
- API keys
- Passwords

See [SECRET_MANAGEMENT.md](guides/SECRET_MANAGEMENT.md)

---

## Configuration

Your configuration files:
- `deployment/group_vars/all.yml` - Main settings (app name, size, etc)
- `deployment/group_vars/vault.yml` - Secrets (GitHub URL, AWS credentials, passwords)
- `deployment/inventories/hosts.yml` - Ansible inventory (server IP, SSH key)

See [PREREQUISITES.md](guides/PREREQUISITES.md) for setup details.

