# Application Maintenance Scripts

**Location:** `app/scripts/`

These scripts are for application maintenance and should be run on the server, not during deployment.

---

## Server Maintenance

### `app-hard-restart.sh`
**Purpose:** Force restart application with complete cache clearing

**Usage:**
```bash
# On the server
cd /home/ubuntu/{app_name}
./app/scripts/app-hard-restart.sh
```

**What it does:**
- Stops application service
- Clears all Python caches (__pycache__, .pyc files)
- Clears Flask and Gunicorn temp files
- Kills any remaining Gunicorn processes
- Starts application fresh
- Verifies service is running
- Tests code functionality

**When to use:**
- After major code changes that don't seem to apply
- When caching issues occur
- After Python dependency updates
- When app behaves unexpectedly despite new code

---

## Image Management

### `fix-missing-thumbnails.py`
**Purpose:** Regenerate missing thumbnail images

**Usage:**
```bash
# On the server
cd /home/ubuntu/{app_name}
source ~/.venv/bin/activate
python3 app/scripts/fix-missing-thumbnails.py
```

**When to use:**
- After bulk image import
- If thumbnails are missing or corrupted
- Database shows items but thumbnails don't display

### `check-comic-images.py`
**Purpose:** Validate image files and check for issues

**Usage:**
```bash
cd /home/ubuntu/{app_name}
source ~/.venv/bin/activate
python3 app/scripts/check-comic-images.py
```

**Checks:**
- Image file exists
- File is valid format (JPEG, PNG)
- Image dimensions are reasonable
- File size is reasonable

### `generate-page-images.py`
**Purpose:** Generate page images for items

**Usage:**
```bash
cd /home/ubuntu/{app_name}
source ~/.venv/bin/activate
python3 app/scripts/generate-page-images.py
```

**When to use:**
- After adding new items
- To regenerate all page images
- After changing page layout template

---

## Data Management

### `validate-csv-schema.py`
**Purpose:** Validate CSV file structure before import

**Usage:**
```bash
cd /home/ubuntu/{app_name}
source ~/.venv/bin/activate
python3 app/scripts/validate-csv-schema.py path/to/file.csv
```

**Validates:**
- CSV has required columns
- Data types are correct
- No missing required fields
- Values are in valid ranges

---

## API Integration

### `generate-ebay-token.sh`
**Purpose:** Generate OAuth token for eBay API

**Usage:**
```bash
cd /home/ubuntu/{app_name}
./app/scripts/generate-ebay-token.sh
```

**When to use:**
- First time eBay API setup
- Token expired (tokens expire every 18 months)
- Changing eBay API credentials

**Requires:**
- eBay App ID, Cert ID, Dev ID in environment or secrets
- Valid eBay developer account

---

## Running Scripts on Server

### 1. SSH to Server
```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@YOUR_SERVER_IP
```

### 2. Navigate to App Directory
```bash
cd /home/ubuntu/{app_name}
```

### 3. Activate Virtual Environment
```bash
source ~/.venv/bin/activate
```

### 4. Run Script
```bash
# Python scripts
python3 app/scripts/fix-missing-thumbnails.py

# Shell scripts
./app/scripts/generate-ebay-token.sh
```

---

## Script Permissions

All scripts should be executable:
```bash
chmod +x app/scripts/*.sh
```

Python scripts don't need execute permission (run with `python3`).

---

## Adding New Scripts

When creating new maintenance scripts:

1. **Place in app/scripts/** (not deployment/scripts)
2. **Use relative paths** from app root
3. **Document in this README**
4. **Include error handling**
5. **Log to app logs** if appropriate

**Example:**
```python
#!/usr/bin/env python3
# app/scripts/my-maintenance-task.py

import sys
import os

# Add app to path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app import create_app

def main():
    app = create_app('production')
    with app.app_context():
        # Your maintenance task here
        pass

if __name__ == '__main__':
    main()
```

---

## Deployment vs Application Scripts

**app/scripts/** - Application maintenance (this directory)
- Image processing
- Data validation
- API token generation
- Database maintenance
- Run on server after deployment

**deployment/scripts/** - Deployment automation
- Infrastructure provisioning
- Secret management
- Deployment orchestration
- Run from local machine during deployment

**Keep these separate!**

---

## Common Tasks

### Fix All Images
```bash
ssh ubuntu@YOUR_SERVER_IP
cd /home/ubuntu/{app_name}
source ~/.venv/bin/activate
python3 app/scripts/check-comic-images.py
python3 app/scripts/fix-missing-thumbnails.py
python3 app/scripts/generate-page-images.py
```

### Validate Data Before Import
```bash
# On local machine first
python3 app/scripts/validate-csv-schema.py data/import.csv

# If valid, upload to server
scp -i ~/.ssh/{app_name}-key.pem data/import.csv ubuntu@YOUR_SERVER_IP:/tmp/

# Then import on server
ssh ubuntu@YOUR_SERVER_IP
cd /home/ubuntu/{app_name}
source ~/.venv/bin/activate
python3 import_script.py /tmp/import.csv
```

### Regenerate eBay Token
```bash
ssh ubuntu@YOUR_SERVER_IP
cd /home/ubuntu/{app_name}
./app/scripts/generate-ebay-token.sh
# Follow prompts, restart app after
sudo systemctl restart {app_name}
```

---

## Troubleshooting

**Script can't find modules:**
```bash
# Make sure you're in app directory
cd /home/ubuntu/{app_name}

# Activate virtual environment
source ~/.venv/bin/activate

# Check Python path
python3 -c "import sys; print(sys.path)"
```

**Permission denied:**
```bash
# Make shell scripts executable
chmod +x app/scripts/*.sh
```

**Images not updating:**
```bash
# Check app user has permission
ls -la /home/ubuntu/{app_name}/instance/item_images/
# Should be owned by {app_name}:{app_name}

# Fix permissions if needed
sudo chown -R {app_name}:{app_name} /home/ubuntu/{app_name}/instance/
```

---

## Summary

**Purpose:** Application maintenance tasks run on the server

**Not for:** Deployment automation (use deployment/scripts or playbooks)

**Run where:** On the server in the app directory

**Run when:** After deployment, during maintenance, or ad-hoc

**Examples:** Fix images, validate data, generate API tokens

