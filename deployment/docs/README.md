# Deployment Documentation

---

## Getting Started

1. [PREREQUISITES.md](guides/PREREQUISITES.md) - Set up AWS account, CLI, Ansible, and configuration
2. [QUICKSTART.md](guides/QUICKSTART.md) - Automated deployment (15-20 min)
3. [MANUAL_DEPLOYMENT.md](guides/MANUAL_DEPLOYMENT.md) - Step-by-step deployment (1-2 hours)

---

## Guides

### Deployment
- [PREREQUISITES.md](guides/PREREQUISITES.md) - First-time setup
- [QUICKSTART.md](guides/QUICKSTART.md) - Automated deployment
- [MANUAL_DEPLOYMENT.md](guides/MANUAL_DEPLOYMENT.md) - Step-by-step deployment
- [UPDATING_APPLICATION.md](guides/UPDATING_APPLICATION.md) - Deploy code changes

### Infrastructure
- [INFRASTRUCTURE.md](guides/INFRASTRUCTURE.md) - AWS resources explained
- [EBS_APPLICATION_STORAGE.md](guides/EBS_APPLICATION_STORAGE.md) - Application storage

### Operations
- [OPERATIONS.md](guides/OPERATIONS.md) - Backups, scaling, troubleshooting
- [MONITORING.md](guides/MONITORING.md) - Logs, alarms, dashboards
- [SECRET_MANAGEMENT.md](guides/SECRET_MANAGEMENT.md) - Secrets and credentials

### Security
- [SECURITY_HARDENING.md](guides/SECURITY_HARDENING.md) - Server hardening
- [MULTI_USER.md](guides/MULTI_USER.md) - Multiple user accounts

### Optional Features
- [CLOUDFRONT_CDN.md](guides/CLOUDFRONT_CDN.md) - Content delivery network
- [WAF_CONFIGURATION.md](guides/WAF_CONFIGURATION.md) - Web application firewall
- [GIT_CONFIGURATION.md](guides/GIT_CONFIGURATION.md) - Git setup

---

## Reference

- [ARCHITECTURE.md](reference/ARCHITECTURE.md) - System design overview
- [APPLICATION_SECURITY.md](reference/APPLICATION_SECURITY.md) - Security layers (WAF, attack detection)
- [SECURITY.md](reference/SECURITY.md) - User isolation model
- [USER_MODEL.md](reference/USER_MODEL.md) - User types and permissions

---

## File Structure

```
docs/
├── guides/                   # How-to guides (step-by-step)
│   ├── PREREQUISITES.md
│   ├── QUICKSTART.md
│   ├── MANUAL_DEPLOYMENT.md
│   ├── UPDATING_APPLICATION.md
│   ├── INFRASTRUCTURE.md
│   ├── EBS_APPLICATION_STORAGE.md
│   ├── OPERATIONS.md
│   ├── MONITORING.md
│   ├── SECRET_MANAGEMENT.md
│   ├── SECURITY_HARDENING.md
│   ├── MULTI_USER.md
│   ├── CLOUDFRONT_CDN.md
│   ├── WAF_CONFIGURATION.md
│   └── GIT_CONFIGURATION.md
│
├── reference/                # Reference material
│   ├── APPLICATION_SECURITY.md
│   ├── ARCHITECTURE.md
│   ├── SECURITY.md
│   └── USER_MODEL.md
│
└── README.md                 # This file
```
