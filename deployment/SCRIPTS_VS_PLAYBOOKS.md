# Deployment Scripts vs Playbooks - Architecture Decision

**Date:** February 15, 2026

---

## Philosophy: Use Ansible Playbooks, Not Shell Scripts

**Principle:** Deployment automation should use Ansible playbooks for consistency, idempotency, and maintainability.

---

## Ansible Playbooks (Primary Deployment Tool)

### Core Deployment Playbooks

**Location:** `deployment/playbooks/`

| Playbook | Purpose | Replaces |
|----------|---------|----------|
| `provision-ec2.yml` | Create EC2 instance, security group, SSH key | `ec2-create-instance.sh` ✅ |
| `setup.yml` | Full application setup (install, configure, start) | Main deployment |
| `update.yml` | Update application code and restart | Application updates |
| `setup-ssl.yml` | Install Let's Encrypt SSL certificate | `ssl-setup.sh` ✅ |
| `setup-monitoring.yml` | Configure CloudWatch and log monitoring | `setup-monitoring.sh` ✅ |
| `security-hardening.yml` | Apply security configurations | Security setup |
| `cleanup-server.yml` | Remove application from server | Cleanup |

### Why Ansible Playbooks?

✅ **Idempotent** - Can run multiple times safely  
✅ **Variables** - Uses group_vars, vault, templates  
✅ **Structured** - Clear tasks, handlers, roles  
✅ **Error handling** - Built-in retries, conditions  
✅ **Consistent** - Same tool for all automation  
✅ **Testable** - Can run in check mode  
✅ **Maintainable** - YAML vs complex bash  

---

## Shell Scripts (Kept - Appropriate Use Cases)

### Wrapper Scripts (Simplify Playbook Execution)

**Location:** `deployment/scripts/`

| Script | Purpose | Why Shell? |
|--------|---------|------------|
| `infra-complete-setup.sh` | Wrapper that orchestrates multiple playbooks | Orchestration wrapper |
| `app-deploy.sh` | Simple wrapper for systemctl commands | Thin wrapper |
| `app-hard-restart.sh` | Force restart application | Thin wrapper |

**Appropriate because:**
- Simple wrappers around existing commands
- Provide shortcuts for common operations
- Not complex deployment logic
- Could be converted to Ansible if needed

### Secret Management Scripts (Complex Logic)

| Script | Purpose | Why Shell? |
|--------|---------|------------|
| `secret-migrate-to-vault.sh` | Migrate secrets to Ansible vault | Complex vault manipulation |
| `secret-promote.sh` | Promote secrets between environments | Environment-specific logic |
| `secret-rotate.sh` | Rotate application secrets | Multi-step secret rotation |
| `secret-sync-vault.sh` | Sync secrets with AWS Secrets Manager | Two-way sync logic |
| `secret-upload-to-aws.sh` | Upload secrets to AWS | AWS-specific operations |

**Appropriate because:**
- Complex conditional logic
- Multiple tool interactions (vault, aws, jq)
- Secret manipulation requires careful handling
- Shell scripts work well for these operations

### Application Utilities (Not Deployment)

| Script | Purpose | Why Shell/Python? |
|--------|---------|-------------------|
| `util-check-comic-images.py` | Validate image files | Application-specific |
| `util-fix-missing-thumbnails.py` | Regenerate thumbnails | Application-specific |
| `util-generate-ebay-token.sh` | Get eBay OAuth token | External API |
| `util-generate-page-images.py` | Generate image pages | Application-specific |
| `util-validate-csv-schema.py` | Validate CSV structure | Application-specific |

**Appropriate because:**
- Application utilities, not deployment automation
- May use application code/libraries
- Run ad-hoc, not part of deployment process

---

## Deleted Scripts (Converted to Ansible)

| Deleted Script | Replaced By | Reason |
|----------------|-------------|--------|
| `manual-generate-systemd.sh` | `setup.yml` + `templates/systemd-with-validation.service.j2` | Redundant - setup.yml already uses templates |
| `manual-generate-nginx.sh` | `setup.yml` + `templates/nginx.conf.j2` | Redundant - setup.yml already uses templates |
| `ec2-create-instance.sh` | `playbooks/provision-ec2.yml` | Better as Ansible playbook |
| `ssl-setup.sh` | `playbooks/setup-ssl.yml` | Better as Ansible playbook |
| `setup-monitoring.sh` | `playbooks/setup-monitoring.yml` | Better as Ansible playbook |

---

## When to Use Shell Script vs Ansible Playbook

### Use Ansible Playbook When:
- ✅ Deploying or configuring servers
- ✅ Installing software packages
- ✅ Managing configuration files (use templates)
- ✅ Starting/stopping services
- ✅ Creating AWS resources
- ✅ Need idempotency (safe to run multiple times)
- ✅ Complex multi-step operations
- ✅ Need to use Ansible variables/vault

### Use Shell Script When:
- ✅ Simple wrapper around existing commands
- ✅ Complex conditional logic better suited to shell
- ✅ One-off utilities or ad-hoc operations
- ✅ Application-specific tasks (not deployment)
- ✅ Interacting with multiple tools in complex ways
- ✅ Secret management (careful manipulation required)

### Never Use Shell Script When:
- ❌ Configuring servers (use Ansible)
- ❌ Installing packages (use Ansible)
- ❌ Managing systemd services (use Ansible)
- ❌ Creating config files (use Ansible templates)
- ❌ Need idempotency (shell scripts often not idempotent)

---

## Current Architecture

```
deployment/
├── playbooks/           # Primary deployment automation
│   ├── provision-ec2.yml       # Create infrastructure
│   ├── setup.yml               # Setup application
│   ├── update.yml              # Update application
│   ├── setup-ssl.yml           # Add SSL
│   ├── setup-monitoring.yml    # Add monitoring
│   ├── security-hardening.yml  # Security config
│   └── cleanup-server.yml      # Cleanup
│
├── templates/           # Ansible templates (Jinja2)
│   ├── nginx.conf.j2
│   ├── systemd-with-validation.service.j2
│   ├── env.j2
│   ├── cloudwatch-config.json.j2
│   ├── log-monitor.sh.j2
│   └── ...
│
├── scripts/            # Shell scripts (limited use)
│   ├── infra-complete-setup.sh    # Wrapper
│   ├── app-deploy.sh              # Wrapper
│   ├── app-hard-restart.sh        # Wrapper
│   ├── secret-*.sh                # Secret management
│   └── util-*.{py,sh}             # Application utilities
│
└── group_vars/         # Ansible variables
    ├── all.yml
    └── production/
        └── vault.yml
```

---

## Usage Examples

### Provision Infrastructure
```bash
ansible-playbook playbooks/provision-ec2.yml
```

### Deploy Application
```bash
ansible-playbook -i inventories/production playbooks/setup.yml
```

### Update Application
```bash
ansible-playbook -i inventories/production playbooks/update.yml
# Or use wrapper:
./scripts/app-deploy.sh update
```

### Add SSL
```bash
ansible-playbook -i inventories/production playbooks/setup-ssl.yml
```

### Add Monitoring
```bash
ansible-playbook -i inventories/production playbooks/setup-monitoring.yml
```

### Manage Secrets
```bash
./scripts/secret-rotate.sh production
./scripts/secret-sync-vault.sh
```

---

## Migration Complete

**Before:** Mix of shell scripts and Ansible playbooks (inconsistent)

**After:** Ansible playbooks for all deployment automation (consistent)

**Result:**
- ✅ Consistent tooling (Ansible)
- ✅ Idempotent operations
- ✅ Better variable management
- ✅ Easier to maintain
- ✅ Professional deployment automation

**Scripts remaining:** Only for appropriate use cases (wrappers, secrets, utilities)

---

## Summary

**Deployment = Ansible Playbooks**
- provision-ec2.yml
- setup.yml
- update.yml
- setup-ssl.yml
- setup-monitoring.yml

**Shell Scripts = Specific Use Cases Only**
- Thin wrappers (app-deploy.sh)
- Secret management (secret-*.sh)
- Application utilities (util-*.py)

**Philosophy:** Use the right tool for the job. Ansible for infrastructure and deployment automation. Shell scripts for simple wrappers and specialized tasks only.

