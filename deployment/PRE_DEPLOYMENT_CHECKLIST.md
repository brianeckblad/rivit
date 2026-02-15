# Pre-Deployment Checklist

**Complete these prerequisites before deployment.**

---

## Quick Verification

Run these commands. If any fail, see below for fixes:

```bash
# 1. AWS configured?
aws sts get-caller-identity

# 2. Python 3.8+ installed?
python3 --version

# 3. Git configured?
git config --list | grep user.name
```

**All work?** ✅ Continue to [Configuration](#configuration)

**Something failed?** ❌ See [Fix Prerequisites](#fix-prerequisites) below

---

## Fix Prerequisites

### 1. AWS CLI Not Configured

**Install AWS CLI:**

```bash
# macOS
brew install awscli

# Ubuntu/Linux
sudo apt install awscli

# Windows
# Download from aws.amazon.com/cli
```

**Configure AWS CLI:**

1. **Create IAM user** in AWS Console:
   - Go to IAM → Users → Create User
   - Name: `{app_name}-deploy`
   - Permissions: `AdministratorAccess`
   - Create access key (CLI type)
   - Save Access Key ID and Secret Access Key

2. **Configure locally:**
   ```bash
   aws configure
   # Access Key ID: AKIA... (from step 1)
   # Secret Access Key: wJalr... (from step 1)
   # Region: us-east-2
   # Format: json
   ```

3. **Verify:**
   ```bash
   aws sts get-caller-identity
   # Should show your account details
   ```

**Multiple AWS accounts?** → See [AWS_PROFILES_GUIDE.md](AWS_PROFILES_GUIDE.md)

### 2. Python Not Installed

```bash
# macOS
brew install python3

# Ubuntu/Linux
sudo apt update && sudo apt install python3 python3-pip python3-venv

# Windows
# Download from python.org
```

Verify: `python3 --version` (should show 3.8+)

### 3. Git Not Configured

```bash
# Install git
brew install git              # macOS
sudo apt install git          # Linux
# Download from git-scm.com   # Windows

# Configure
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**GitHub Authentication:**

**Option A: Personal Access Token**
1. Go to GitHub Settings → Developer settings → Tokens
2. Generate new token (classic)
3. Select `repo` scope
4. Copy token
5. Use token as password when cloning

**Option B: SSH Key**
```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub  # Copy this
# Add to GitHub Settings → SSH Keys
```

---

## Configuration

### 1. Clone Repository and Install Dependencies

```bash
# Clone your repository
git clone https://github.com/YOUR_USERNAME/your_app_name.git
cd your_app_name

# Install deployment dependencies
pip3 install -r deployment/requirements.txt

# This installs: ansible, boto3, awscli, and all deployment tools
```

**Verify:**
```bash
pip3 list | grep -E "ansible|boto3|awscli"
# Should show all three packages
```

### 2. Configure Application Name

Edit `deployment/group_vars/all.yml`:
```yaml
app_name: CHANGEME           # ⚠️ Change to your app name (e.g., myapp)
app_display_name: "CHANGE ME" # ⚠️ Change to display name (e.g., "My App")
```

### 3. Create Secrets Vault

```bash
cd deployment

# Create vault password file
echo "your-secure-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Create encrypted vault
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

**Add this content to vault:**
```yaml
---
# Git Repository
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app_name.git"

# AWS
vault_aws_region: "us-east-2"
vault_s3_bucket_name: "yourname-yourapp-2026"  # Must be globally unique!
vault_s3_folder: "production"

# App Login Credentials (you choose these)
vault_app_username: "admin"
vault_app_password: "create-a-strong-password"

# Optional: eBay (leave blank if not using)
vault_ebay_app_id: ""
vault_ebay_cert_id: ""
vault_ebay_dev_id: ""
vault_ebay_token: ""

# Optional: SNS
vault_sns_topic_arn: ""
```

**Save and exit** (vim: Esc → `:wq` → Enter)

### 4. Create S3 Bucket

```bash
# Choose a globally unique name
aws s3 mb s3://yourname-yourapp-2026 --region us-east-2
```

**Bucket name rules:**
- Must be globally unique across ALL AWS
- Lowercase letters, numbers, hyphens only
- Example: `brian-comictracker-2026`

---

## Verification

Run these to verify configuration:

```bash
# 1. App name set?
grep "app_name:" deployment/group_vars/all.yml
# Should NOT show "CHANGEME"

# 2. Vault created?
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass | grep vault_git_repo
# Should show YOUR GitHub repo URL

# 3. S3 bucket exists?
aws s3 ls s3://yourname-yourapp-2026
# Should work (even if empty)
```

**All pass?** ✅ Ready to deploy!

---

## Deploy

**Automated (recommended):**
```bash
cd deployment
./scripts/infra-complete-setup.sh
```
→ See [AUTOMATED_DEPLOYMENT.md](AUTOMATED_DEPLOYMENT.md)

**Manual:**
```bash
# Create EC2 instance first, then:
cd deployment
ansible-playbook -i inventories/production playbooks/setup.yml
```
→ See [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md)

---

## Common Issues

**"InvalidClientTokenId"** → AWS credentials wrong, run `aws configure` again

**"NoSuchBucket"** → Run `aws s3 mb s3://your-bucket-name --region us-east-2`

**"ansible: command not found"** → Run `pip3 install -r deployment/requirements.txt`

**Can't decrypt vault** → Check `~/.vault_pass` file exists and has correct password

---

## That's It

✅ Prerequisites installed
✅ Configuration files created  
✅ Ready to deploy

Choose your deployment method above and follow that guide.

