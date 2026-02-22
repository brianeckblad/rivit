# Git Configuration Guide

**Configure git to automatically use your app email**

---

## Problem

You want `git config user.email` to automatically use your app's email domain without configuring it globally.

## Solutions

### Option 1: Automatic Script (Recommended)

Use the provided script to automatically extract your app's email from deployment config:

```bash
cd deployment
./scripts/configure-git.sh
```

**What it does:**
1. Reads `group_vars/all.yml` for your `ssl_email`
2. Sets git to use that email
3. Asks if you want local (this repo) or global (all repos) configuration

**Example:**
```bash
$ ./scripts/configure-git.sh

Git Configuration Setup
==================================================

📝 Configuration detected:
   App name: rampe
   Email: rampe@ipix.io
   Domain: rampe.ipix.io

Configure git for:
  1. This repository only (local)
  2. All repositories (global)

Choose 1 or 2 [default: 1]: 1
Git user name (for this repo) [default: rampe]: testpilot

✅ Local git config set (.git/config)

Your commits will now use:
   Author: testpilot <rampe@ipix.io>
```

---

### Option 2: Manual Setup (Per Repository)

Set git email for just this repo:

```bash
cd /path/to/rampe

# Set email for this repo only
git config user.email "testpilot@ipix.io"
git config user.name "testpilot"

# Verify
git config user.email
# Shows: testpilot@ipix.io
```

**Location:** `.git/config` (not shared, not in version control)

---

### Option 3: Global Configuration (All Repos)

Set git email globally for all repositories:

```bash
# Set globally (affects all repos on this machine)
git config --global user.email "testpilot@example.com"
git config --global user.name "testpilot"

# Verify
git config --global user.email
# Shows: testpilot@example.com
```

**Location:** `~/.gitconfig` (your home directory)

**Problem:** If you work on multiple projects with different emails, this isn't ideal.

---

### Option 4: Conditional Configuration (Git 2.13+)

Use git's `conditional.includeIf` to automatically switch emails based on directory:

```bash
# Edit your global git config
nano ~/.gitconfig
```

Add this at the end:

```ini
[includeIf "gitdir:~/Development/rampe/"]
    path = ~/Development/rampe/.gitconfig-local
```

Then create `.gitconfig-local` in the rampe directory:

```ini
[user]
    name = testpilot
    email = testpilot@ipix.io
```

**How it works:**
- When you're in `~/Development/rampe/`, git uses `.gitconfig-local`
- When you're elsewhere, git uses your global `~/.gitconfig`
- Automatically switches based on directory

**Check git version:**
```bash
git --version
# Need 2.13 or higher
```

---

## Recommendation

**Use Option 1 (Automatic Script)** because:
- ✅ Automatically reads from your deployment config
- ✅ No manual email typing required
- ✅ Works with any git version
- ✅ Easy one-command setup
- ✅ Can configure per-repo or globally

**Then just run once:**
```bash
cd deployment
./scripts/configure-git.sh
# Choose "1" for local (this repo only)
```

---

## Verify It's Working

```bash
# Check what email git will use
git config user.email
# Should show: testpilot@ipix.io (or whatever you configured)

# Check where it's configured
git config --show-origin user.email
# Shows: file:.git/config (local) or file:~/.gitconfig (global)

# Make a test commit to verify
git add README.md
git commit -m "test: verify git config"
git log -1 --format=fuller
# Should show your configured email
```

---

## Why Not Global?

**Global config (Option 3) has issues:**
- If you work on multiple projects, all use the same email
- Different projects might need different emails
- Need to remember to set it
- Can't use variables

**Local config (Option 2, 1, 4) is better:**
- Each project has its own email
- Can be different per project
- Can be automated
- More professional

---

## Integration with Deployment

The script `./scripts/configure-git.sh` is meant to be run after:

1. `./scripts/local-dev-setup.sh` - Creates your config files
2. `./scripts/configure-git.sh` - Sets up git with your app email

Both are optional but recommended.

---

## Troubleshooting

**"git config: command not found"**
```bash
# Install git
brew install git  # macOS
sudo apt install git  # Linux
```

**"Could not read configuration from group_vars/all.yml"**
```bash
# Run local-dev-setup.sh first
cd deployment
./scripts/local-dev-setup.sh

# Then try git config script
./scripts/configure-git.sh
```

**Want to change it later?**
```bash
# For local repo
git config user.email "newemail@domain.com"

# For global
git config --global user.email "newemail@domain.com"
```

---

## Quick Start

```bash
# From deployment directory
cd deployment

# Step 1: Create config (if not done yet)
./scripts/local-dev-setup.sh

# Step 2: Configure git with your app email
./scripts/configure-git.sh

# Step 3: Done! Your commits will use testpilot@ipix.io (or your configured email)
```

