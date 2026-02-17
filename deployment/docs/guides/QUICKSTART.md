# Quickstart Guide

**Get your application deployed in 15-20 minutes**

---

## Prerequisites (5 minutes)

### 1. Install Tools

```bash
# Check if you have these
aws sts get-caller-identity    # AWS CLI
python3 --version              # Python 3.8+
ansible --version              # Ansible 2.9+

# If missing, install
pip3 install -r deployment/requirements.txt
```

### 2. Setup Configuration Files

**Use the standard `.example` file pattern:**

```bash
cd deployment

# Automatic setup (recommended)
./scripts/local-dev-setup.sh

# This creates your config files from templates:
#   all.yml.example       → all.yml (your config)
#   vault.yml.example     → vault.yml (your secrets)
```

**How it works:**
- `.example` files = Templates (in Git, get updates)
- Real files = Your settings (ignored by Git, stay private)

**Standard pattern used by npm, docker, and most tools.**

### 3. Configure Application

```bash
cd deployment

# Edit YOUR config file (ignored by Git)
nano group_vars/all.yml
```

**Change these:**
```yaml
app_name: myapp                    # Your app name
app_display_name: "My App"         # Display name
server_name: "_"                   # Domain or "_" for IP-only
ssl_email: "you@example.com"       # Email for SSL notifications
```

### 4. Create Secrets Vault

```bash
# Create vault password
echo "your-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Edit your secrets file (created by local-dev-setup.sh)
nano group_vars/vault.yml
```

**Add this:**
```yaml
---
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app.git"
vault_aws_region: "us-east-2"
vault_s3_bucket_name: "yourname-yourapp-2026"
vault_s3_folder: "data"
vault_app_username: "admin"
vault_app_password: "strong-password-here"
```

**(Optional) Encrypt it:**
```bash
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass
```

---

## Deploy (15 minutes)

### Option 1: Complete Automation

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

**Done!** Application will be running at the IP shown.

### Option 2: Step by Step

```bash
cd deployment

# 1. Create S3 bucket
aws s3 mb s3://yourname-yourapp-2026 --region us-east-2

# 2. Provision infrastructure (IAM, EC2, security group, SSH key)
ansible-playbook playbooks/provision-infrastructure.yml

# 3. Update inventory with IP from output
nano inventories/hosts.yml
# Set: ansible_host: YOUR_INSTANCE_IP

# 4. Deploy application
ansible-playbook -i inventories playbooks/setup.yml
```

**Done!** Application running at `http://YOUR_INSTANCE_IP`

---

## Add SSL (Optional - 5 minutes)

**Only if you have a domain name**

```bash
# 1. Point DNS to your server IP
# Create A record: your-domain.com → YOUR_SERVER_IP

# 2. Wait for DNS propagation (5-30 minutes)
nslookup your-domain.com

# 3. Update configuration
nano deployment/group_vars/all.yml
# Set: server_name: "your-domain.com"

# 4. Setup SSL
ansible-playbook -i inventories playbooks/setup-ssl.yml
```

**Done!** Application at `https://your-domain.com`

---

## Verify

```bash
# Test application
curl http://YOUR_INSTANCE_IP
# or
curl https://your-domain.com

# Check logs
ssh -i ~/.ssh/myapp-key.pem ubuntu@YOUR_INSTANCE_IP
sudo journalctl -u myapp -n 50
```

---

## What You Just Created

| Resource | Details |
|----------|---------|
| **EC2 Instance** | Ubuntu 22.04, t3.micro |
| **S3 Bucket** | Image storage |
| **Application** | Running with Gunicorn + Nginx |
| **SSL** | Let's Encrypt (if domain configured) |
| **IAM Role** | S3, Secrets Manager, CloudWatch access |

**Cost:** ~$10-15/month (or ~$2/month on AWS free tier)

---

## Next Steps

- **Update app:** `ansible-playbook -i inventories playbooks/update.yml`
- **View logs:** `ssh ubuntu@IP` then `sudo journalctl -u myapp`
- **Add users:** See [MULTI_USER.md](MULTI_USER.md)
- **Operations:** See [OPERATIONS.md](OPERATIONS.md)

---

## Troubleshooting

**Can't access application?**
```bash
# Check security group
aws ec2 describe-security-groups --group-names myapp-sg

# Should show ports 22, 80, 443 open
```

**Service won't start?**
```bash
ssh ubuntu@YOUR_IP
sudo journalctl -u myapp -n 100
# Check for errors
```

**Need detailed help?** → [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md)

---

## Summary

✅ **Deployed in 15-20 minutes**  
✅ **Production-ready application**  
✅ **Secure configuration**  
✅ **SSL-ready (if domain provided)**  

**Your application is running!** 🎉

