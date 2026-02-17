# Playbook Reference

**All playbooks and their purposes**

---

## Infrastructure Playbooks

| Playbook | Purpose | Usage |
|----------|---------|-------|
| `create-s3-bucket.yml` | Create S3 bucket | `ansible-playbook playbooks/create-s3-bucket.yml` |
| `create-iam-role.yml` | Create IAM role with policies | `ansible-playbook playbooks/create-iam-role.yml` |
| `create-security-group.yml` | Create security group | `ansible-playbook playbooks/create-security-group.yml` |
| `create-ssh-key.yml` | Create SSH key pair | `ansible-playbook playbooks/create-ssh-key.yml` |
| `launch-ec2-instance.yml` | Launch EC2 instance | `ansible-playbook playbooks/launch-ec2-instance.yml` |
| `provision-infrastructure.yml` | Run all 5 above in order | `ansible-playbook playbooks/provision-infrastructure.yml` |
| `provision-complete.yml` | Full deployment | `ansible-playbook playbooks/provision-complete.yml` |

## Application Playbooks

| Playbook | Purpose | Usage |
|----------|---------|-------|
| `setup.yml` | Deploy application | `ansible-playbook -i inventories playbooks/setup.yml` |
| `update.yml` | Update application | `ansible-playbook -i inventories playbooks/update.yml` |
| `remote-update.yml` | Remote update | `ansible-playbook -i inventories playbooks/remote-update.yml` |

## Security Playbooks

| Playbook | Purpose | Usage |
|----------|---------|-------|
| `setup-ssl.yml` | Install SSL certificate | `ansible-playbook -i inventories playbooks/setup-ssl.yml` |
| `setup-waf.yml` | Configure AWS WAF | `ansible-playbook playbooks/setup-waf.yml` |
| `security-hardening.yml` | Apply OS hardening | `ansible-playbook -i inventories playbooks/security-hardening.yml` |

## Monitoring & CDN Playbooks

| Playbook | Purpose | Usage |
|----------|---------|-------|
| `setup-monitoring.yml` | Configure CloudWatch | `ansible-playbook -i inventories playbooks/setup-monitoring.yml` |
| `setup-cloudfront.yml` | Create CloudFront CDN | `ansible-playbook playbooks/setup-cloudfront.yml` |

## Secret Management Playbooks

| Playbook | Purpose | Usage |
|----------|---------|-------|
| `setup-secrets-manager.yml` | Create AWS secret | `ansible-playbook playbooks/setup-secrets-manager.yml` |
| `secret-sync.yml` | Sync vault to AWS | `ansible-playbook playbooks/secret-sync.yml` |
| `secret-rotate.yml` | Rotate secret | `ansible-playbook playbooks/secret-rotate.yml -e secret_key=KEY` |
| `secret-promote.yml` | Promote secret | `ansible-playbook playbooks/secret-promote.yml -e secret_key=KEY` |

## Maintenance Playbooks

| Playbook | Purpose | Usage |
|----------|---------|-------|
| `cleanup-server.yml` | Remove application | `ansible-playbook -i inventories playbooks/cleanup-server.yml` |

---

## Quick Reference

**First deployment:**
```bash
ansible-playbook playbooks/provision-infrastructure.yml
ansible-playbook -i inventories playbooks/setup.yml
```

**Update application:**
```bash
ansible-playbook -i inventories playbooks/update.yml
```

**Add SSL:**
```bash
ansible-playbook -i inventories playbooks/setup-ssl.yml
```

---

## Reusable Tasks

**Location:** `playbooks/tasks/`

| Task | Purpose | Used By |
|------|---------|---------|
| `harden-permissions.yml` | Set file permissions | setup.yml, update.yml, security-hardening.yml |

**Not run directly** - included by other playbooks

---

## Total: 20 playbooks

- Infrastructure: 7
- Application: 3
- Security: 3
- Monitoring & CDN: 2
- Secret Management: 4
- Maintenance: 1

