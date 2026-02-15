# Pre-Deployment Checklist

**Use this before deploying** - Either automated or manual deployment.

---

## Quick Check: Are You Ready?

Run these commands. If any fail, see [Fix It](#fix-it) section:

```bash
# AWS configured?
aws sts get-caller-identity

# Tools installed?
python3 --version  # Need 3.8+
ansible --version  # Need 2.9+

# Deployment requirements installed?
pip3 list | grep -E "ansible|boto3|awscli"
# Should show all three packages

# Configuration ready?
ls deployment/group_vars/all.yml
ls deployment/group_vars/production/vault.yml
```

**All working?** → You're ready! Skip to [Configuration Check](#configuration-check)

**Something failed?** → See [Fix It](#fix-it) below

---

## Fix It

### AWS CLI Not Configured

#### Step 1: Create AWS Account (If You Don't Have One)

1. Go to [aws.amazon.com](https://aws.amazon.com)
2. Click "Create an AWS Account"
3. Follow the registration process (credit card required)
4. Verify your email and phone number
5. Choose "Basic Support - Free"

#### Step 2: Create IAM User for Deployment

1. Log into [AWS Console](https://console.aws.amazon.com)
2. Go to **IAM** service (search in top bar)
3. Click **Users** in left sidebar
4. Click **Create User** button
5. **User name:** `{app_name}-deploy` (e.g., `myapp-deploy`)
6. Click **Next**
7. **Permissions:** Select "Attach policies directly"
8. Search for and check: **AdministratorAccess**
9. Click **Next**, then **Create user**

#### Step 3: Create Access Keys

1. Click on the user you just created
2. Click **Security credentials** tab
3. Scroll to **Access keys** section
4. Click **Create access key**
5. Select **Command Line Interface (CLI)**
6. Check "I understand..." and click **Next**
7. (Optional) Add description tag
8. Click **Create access key**
9. **IMPORTANT:** Copy both:
   - Access key ID: `AKIA...`
   - Secret access key: `wJalr...`
   - Or click **Download .csv file**

**Keep these credentials safe!** You'll need them in the next step.

#### Step 4: Install AWS CLI

**macOS:**
```bash
# Using Homebrew (recommended)
brew install awscli

# Or using pip
pip3 install awscli

# Verify installation
aws --version
# Should show: aws-cli/2.x.x or higher
```

**Ubuntu/Debian Linux:**
```bash
# Install AWS CLI
sudo apt update
sudo apt install awscli

# Or use pip for latest version
pip3 install awscli --upgrade --user

# Verify installation
aws --version
```

**Windows:**
1. Download installer from [aws.amazon.com/cli](https://aws.amazon.com/cli/)
2. Run the MSI installer
3. Open Command Prompt or PowerShell
4. Run: `aws --version`

#### Step 5: Configure AWS CLI

**Basic Configuration (Single Account):**
```bash
aws configure

# You'll be prompted for:
AWS Access Key ID [None]: AKIA...          # Paste your Access Key ID
AWS Secret Access Key [None]: wJalr...     # Paste your Secret Access Key
Default region name [None]: us-east-1      # Enter: us-east-1
Default output format [None]: json         # Enter: json
```

**What these mean:**
- **Access Key ID:** Your IAM user identifier (starts with AKIA)
- **Secret Access Key:** Your password (long string of random characters)
- **Region:** AWS datacenter location (us-east-1 = US East, Virginia)
- **Output format:** How AWS CLI shows results (json is most common)

**Managing Multiple Accounts/Regions?**

If you need to work with multiple AWS accounts or regions (e.g., separate dev/staging/production), use **named profiles**:

```bash
# Configure production account
aws configure --profile myapp-production
# Enter production credentials and region

# Configure staging account
aws configure --profile myapp-staging
# Enter staging credentials and region

# Use a specific profile
aws s3 ls --profile myapp-production
```

**Full guide:** → [AWS_PROFILES_GUIDE.md](AWS_PROFILES_GUIDE.md)

#### Step 6: Verify AWS CLI Configuration

```bash
# Test AWS CLI is configured correctly
aws sts get-caller-identity

# Should output something like:
# {
#     "UserId": "AIDAI...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/myapp-deploy"
# }
```

**If you see this output, AWS CLI is configured correctly!** ✅

**If you get an error:**
- `Unable to locate credentials`: Run `aws configure` again
- `InvalidClientTokenId`: Check your Access Key ID is correct
- `SignatureDoesNotMatch`: Check your Secret Access Key is correct

#### Troubleshooting AWS Configuration

**Where are credentials stored?**
```bash
# View your credentials file
cat ~/.aws/credentials

# Should show:
# [default]
# aws_access_key_id = AKIA...
# aws_secret_access_key = wJalr...
```

**To reconfigure:**
```bash
# Reconfigure AWS CLI (overwrites existing)
aws configure

# Or manually edit
nano ~/.aws/credentials
nano ~/.aws/config
```

### Python/Ansible Not Installed

#### Step 1: Install Python 3.8+

**macOS:**
```bash
# Using Homebrew (recommended)
brew install python3

# Verify
python3 --version
# Should show: Python 3.8 or higher
```

**Ubuntu/Debian Linux:**
```bash
# Update package list
sudo apt update

# Install Python 3
sudo apt install python3 python3-pip python3-venv

# Verify
python3 --version
# Should show: Python 3.8 or higher
```

**Windows:**
1. Download from [python.org/downloads](https://www.python.org/downloads/)
2. Run installer
3. **IMPORTANT:** Check "Add Python to PATH" during installation
4. Open Command Prompt
5. Run: `python --version`

#### Step 2: Install Ansible

**macOS:**
```bash
# Using Homebrew
brew install ansible

# Verify
ansible --version
# Should show: ansible [core 2.9+]
```

**Ubuntu/Debian Linux:**
```bash
# Install Ansible
sudo apt update
sudo apt install ansible

# Or use pip for latest version
pip3 install ansible

# Verify
ansible --version
```

**Windows:**
Ansible doesn't run natively on Windows. Options:
1. **WSL (Windows Subsystem for Linux)** - Recommended:
   ```bash
   # In PowerShell (as Administrator)
   wsl --install
   # Restart computer
   # Then in WSL Ubuntu:
   sudo apt update
   sudo apt install ansible
   ```

2. **Use from Docker:**
   ```bash
   docker run --rm -it -v ${PWD}:/ansible ansible/ansible:latest
   ```

3. **Control from Linux VM or Mac** (easiest for beginners)

#### Step 3: Install Deployment Requirements

After installing Python and Ansible, install the project's deployment dependencies:

```bash
# Clone the repository first (if you haven't already)
git clone https://github.com/YOUR_USERNAME/your_app_name.git
cd your_app_name

# Install deployment requirements
pip3 install -r deployment/requirements.txt

# This installs:
# - ansible (if not already installed system-wide)
# - boto3 (AWS SDK for Python)
# - awscli (if not already installed)
# - Other deployment tools
```

**Verify installation:**
```bash
# Check installed packages
pip3 list | grep -E "ansible|boto3|awscli"

# Should show:
# ansible         2.15.0 (or higher)
# boto3           1.28.0 (or higher)
# awscli          1.29.0 (or higher)
```

**Troubleshooting:**
- **Permission denied:** Use `pip3 install --user -r deployment/requirements.txt`
- **pip not found:** Install pip: `sudo apt install python3-pip` (Linux) or `brew install python3` (macOS)
- **Old versions:** Upgrade pip: `pip3 install --upgrade pip`

### Git Not Installed/Configured

#### Step 1: Install Git

**macOS:**
```bash
# Using Homebrew
brew install git

# Or use Xcode Command Line Tools
xcode-select --install

# Verify
git --version
```

**Ubuntu/Debian Linux:**
```bash
# Install git
sudo apt update
sudo apt install git

# Verify
git --version
```

**Windows:**
1. Download from [git-scm.com](https://git-scm.com/download/win)
2. Run installer
3. Use default settings (or "Use Git from Git Bash only")
4. Verify: Open Git Bash and run `git --version`

#### Step 2: Configure Git (First Time Setup)

```bash
# Set your name (will appear in commits)
git config --global user.name "Your Name"

# Set your email (should match GitHub email)
git config --global user.email "your.email@example.com"

# Verify configuration
git config --list | grep user
# Should show:
# user.name=Your Name
# user.email=your.email@example.com
```

#### Step 3: Set Up Git Authentication for GitHub

**Option 1: Personal Access Token (Recommended)**

1. Go to [GitHub Settings](https://github.com/settings/tokens)
2. Click **Developer settings** → **Personal access tokens** → **Tokens (classic)**
3. Click **Generate new token** → **Generate new token (classic)**
4. **Note:** "Deployment token"
5. **Expiration:** Choose expiration (90 days or custom)
6. **Scopes:** Check:
   - `repo` (full control of private repositories)
7. Click **Generate token**
8. **COPY THE TOKEN** (you won't see it again!)

**Use the token when cloning:**
```bash
# When prompted for password, use the token (not your GitHub password)
git clone https://github.com/YOUR_USERNAME/your_app_name.git
Username: YOUR_USERNAME
Password: ghp_...  # Paste your token here
```

**Store credentials (so you don't have to enter token every time):**
```bash
# Cache credentials for 1 hour
git config --global credential.helper 'cache --timeout=3600'

# Or store permanently (less secure)
git config --global credential.helper store
```

**Option 2: SSH Key (More Secure)**

1. **Generate SSH key:**
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   # Press Enter for default location (~/.ssh/id_ed25519)
   # Enter passphrase (or press Enter for none)
   ```

2. **Copy public key:**
   ```bash
   # macOS/Linux
   cat ~/.ssh/id_ed25519.pub | pbcopy  # macOS
   cat ~/.ssh/id_ed25519.pub           # Linux (copy manually)
   
   # Windows
   type %USERPROFILE%\.ssh\id_ed25519.pub
   ```

3. **Add to GitHub:**
   - Go to [GitHub SSH Settings](https://github.com/settings/keys)
   - Click **New SSH key**
   - Title: "Deployment key"
   - Paste your public key
   - Click **Add SSH key**

4. **Test connection:**
   ```bash
   ssh -T git@github.com
   # Should show: Hi YOUR_USERNAME! You've successfully authenticated...
   ```

5. **Clone using SSH:**
   ```bash
   git clone git@github.com:YOUR_USERNAME/your_app_name.git
   ```

#### Step 4: Verify Git is Working

```bash
# Clone a test repository
git clone https://github.com/YOUR_USERNAME/your_app_name.git
cd your_app_name

# Check status
git status

# If this works, Git is configured correctly!
```

### Configuration Files Missing

**1. Configure app settings:**

Edit `deployment/group_vars/all.yml`:
```yaml
app_name: your_app_name                      # Your app name (e.g., myapp, inventory_tool, etc.)
app_display_name: "Your App"                 # Display name
```

**Note:** Git repository URL is configured in vault.yml as `vault_git_repo` (see step 2 below)

**2. Create secrets vault:**

```bash
# Create vault password file (one-time)
echo "your-secure-password-here" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Create vault
cd deployment
ansible-vault create group_vars/production/vault.yml --vault-password-file ~/.vault_pass
```

Add this content to the vault:
```yaml
---
# Git Repository
vault_git_repo: "https://github.com/YOUR_USERNAME/your_app_name.git"  # ← Your repo

# AWS
vault_aws_region: "us-east-1"
vault_s3_bucket_name: "your-unique-bucket-name"  # ← Must be globally unique
vault_s3_folder: "production"

# App Credentials
vault_app_username: "admin"
vault_app_password: "your-secure-password"  # ← Change this

# SNS (optional)
vault_sns_topic_arn: ""

# eBay (optional - leave blank if not using)
vault_ebay_app_id: ""
vault_ebay_cert_id: ""
vault_ebay_dev_id: ""
vault_ebay_token: ""
```

---

## Configuration Check

Verify your configuration before deploying:

### 1. App Name Configuration

```bash
grep "app_name:" deployment/group_vars/all.yml
# Should show your actual app name, not "CHANGEME"
```

### 2. Vault Configuration

```bash
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass | grep vault_git_repo
# Should show YOUR repository URL
```

### 3. S3 Bucket Name

The bucket name must be **globally unique** across all AWS:

```bash
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass | grep vault_s3_bucket_name
# Should NOT be: your-bucket-name, your_app_name, or anything common
# Should BE: something unique like: yourname-yourapp-comics-2026
```

**Test if bucket name is available:**
```bash
aws s3 ls s3://your-chosen-bucket-name 2>&1
# Should show: "NoSuchBucket" (good - it's available!)
# If shows content: Choose a different name
```

### 4. Domain (if using SSL)

If you want SSL/custom domain:

```bash
grep "DOMAIN=" deployment/scripts/ssl-setup.sh
# Should show your actual domain, not "your-domain.com"
```

---

## AWS Setup (Required)

### Create S3 Bucket

```bash
# Replace with your unique bucket name
aws s3 mb s3://yourname-yourapp-comics-2026 --region us-east-1
```

### For Manual Deployment: Create EC2 Instance

**Only if doing manual deployment** (automated deployment creates this for you):

```bash
# Launch Ubuntu 22.04 instance
# Instance type: t3.micro (or t3.nano for cheapest)
# Security group: Allow ports 22, 80, 443
# Key pair: Create and download .pem file
```

**Automated deployment?** Skip this - the script handles it.

---

## Final Checklist

Before running deployment, verify:

### Required (Must Have)
- [ ] AWS CLI configured (`aws sts get-caller-identity` works)
- [ ] Python 3.8+ installed
- [ ] Ansible installed
- [ ] **Deployment requirements installed** (`pip3 install -r deployment/requirements.txt`)
- [ ] `deployment/group_vars/all.yml` configured (app_name set)
- [ ] `deployment/group_vars/production/vault.yml` created and configured (vault_git_repo set)
- [ ] `~/.vault_pass` file created
- [ ] S3 bucket created in AWS
- [ ] S3 bucket name is globally unique

### For Manual Deployment Only
- [ ] EC2 instance running Ubuntu 22.04
- [ ] SSH access to EC2 instance
- [ ] Instance IP added to `deployment/inventories/production/hosts`

### For Automated Deployment Only
- [ ] IAM user has `AdministratorAccess` policy
- [ ] Ready to wait 15-20 minutes for full setup

### Optional (Can Skip)
- [ ] Domain name ready (for SSL)
- [ ] Domain updated in `deployment/scripts/ssl-setup.sh`
- [ ] eBay credentials (if using price lookup)

---

## Common Mistakes

### ❌ Using Default Bucket Name

```yaml
# DON'T:
vault_s3_bucket_name: "your_app_name"
vault_s3_bucket_name: "your-bucket-name"

# DO:
vault_s3_bucket_name: "yourname-yourapp-comics-2026"
```


### ❌ Not Updating vault_git_repo

```yaml
# DON'T:
vault_git_repo: "https://github.com/yourusername/your_app_name.git"

# DO:
vault_git_repo: "https://github.com/brian/your_app_name.git"  # Your actual repo
```

### ❌ Forgetting vault password

If you lose `~/.vault_pass`:
- You can't decrypt vault.yml
- You'll need to recreate it from scratch
- **Keep ~/.vault_pass backed up!**

---

## Verification Commands

Run these before deploying to catch issues:

```bash
# 1. AWS works
aws s3 ls
# Should list buckets (even if empty list)

# 2. S3 bucket exists
aws s3 ls s3://your-bucket-name/
# Should work (even if empty)

# 3. Vault can be read
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass
# Should show your secrets

# 4. Vault has your GitHub repo
ansible-vault view deployment/group_vars/production/vault.yml --vault-password-file ~/.vault_pass | grep vault_git_repo
# Should show YOUR repository URL with your username

# 5. Ansible can find inventory (manual deployment only)
ansible-inventory -i deployment/inventories/production --list
# Should show your EC2 instance
```

---

## What If I Skip This?

**If you skip this checklist:**
- Deployment will fail
- You'll waste 10-15 minutes
- You'll have to debug and re-run
- Might create AWS resources you need to clean up

**5 minutes checking now = saves 30 minutes later** ✅

---

## Ready to Deploy?

### For Automated Deployment

```bash
cd deployment
./scripts/infra-complete-setup.sh
```

→ See [README.md#quick-deploy-automated](README.md#quick-deploy-automated)

### For Manual Deployment

```bash
cd deployment
ansible-playbook -i inventories/production playbooks/setup.yml
```

→ See [README.md#manual-deploy-step-by-step](README.md#manual-deploy-step-by-step)

---

## Need Help?

- **Can't configure AWS?** → [AWS Account Setup](#aws-setup-required)
- **Don't understand vault?** → [Fix It → Configuration Files Missing](#configuration-files-missing)
- **Deployment failed?** → [README.md#troubleshooting](README.md#troubleshooting)
- **Something else?** → Check [OPERATIONS.md](OPERATIONS.md) or create GitHub issue

