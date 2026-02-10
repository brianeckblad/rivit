# Listing App

> A modern, production-ready Flask web application and command-line tool for managing and uploading comic book inventory to Whatnot and eBay marketplaces.

[![Python 3.8+](https://img.shields.io/badge/Python-3.8%2B-blue)](https://www.python.org/downloads/)
[![Flask 3.0+](https://img.shields.io/badge/Flask-3.0%2B-green)](https://flask.palletsprojects.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Overview

This application streamlines the entire comic book inventory management workflow:

- **📋 Catalog** comics with detailed information and multiple images
- **📤 Upload** images to AWS S3 with automatic processing and CDN optimization
- **📊 Export** marketplace-compatible CSV files for bulk listing
- **💰 Research** eBay pricing and market trends
- **🏷️ Generate** SKU labels for physical organization
- **🔄 Sync** inventory across multiple instances reliably

Perfect for comic book dealers, collectors, and marketplace sellers who need professional inventory management at scale.

---

## Quick Start

Get the application running in under 5 minutes:

```bash
# 1. Clone and setup
git clone https://github.com/yourusername/app_item_listing_tool.git
cd app_item_listing_tool

# 2. Optional: Rename the app (see deployment/DEPLOYMENT_PREP.md)
#    Edit deployment/group_vars/all.yml to change:
#    - app_name (technical name for paths/services)
#    - app_display_name (display name)
#    - app_url (your repository URL)

# 3. Setup Python environment
python3 -m venv .venv
source .venv/bin/activate

# 4. Install dependencies
pip3 install -r requirements.txt

# 5. Configure environment
cp .env.example .env
# Edit .env with your AWS and eBay credentials

# 6. Initialize directories
mkdir -p instance/{uploads,item_images}

# 7. Run the application
python runapp.py
```

Access the application at `http://localhost:8000`

**Note:** Before deploying to production, configure your app identity in `deployment/group_vars/all.yml` (app_name, app_display_name, app_url). See [deployment/DEPLOYMENT_PREP.md](deployment/DEPLOYMENT_PREP.md#application-configuration) for details.

---

## Deployment & Operations

**For complete deployment instructions, see:** [`deployment/DEPLOYMENT.md`](./deployment/DEPLOYMENT.md)

This guide covers:
- ✅ **Remote Deployment (Recommended)** - One-command automated setup
- ✅ **Local Deployment (Legacy)** - Manual Ansible playbooks
- ✅ **Server Management** - Updates, maintenance, rollback
- ✅ **Architecture & Security** - System design and hardening
- ✅ **Troubleshooting & FAQ** - Common issues and solutions

## Documentation

Additional documentation organized by topic:

### 🏗️ Development & Architecture
| Document | Purpose |
|----------|---------|
| [PROJECT_STRUCTURE.md](deployment/docs/PROJECT_STRUCTURE.md) | Codebase organization, design patterns, and conventions |
| [AWS-SSM-SECRETS.md](deployment/docs/AWS-SSM-SECRETS.md) | AWS Systems Manager integration for credential management |
| [SECURITY.md](deployment/docs/SECURITY.md) | Security hardening, best practices, and compliance |
| [BACKUP_SYSTEMS.md](deployment/docs/BACKUP_SYSTEMS.md) | Backup mechanisms, recovery procedures, and data retention |

### 🔌 Marketplace Integrations
| Document | Purpose |
|----------|---------|
| [EBAY-README.md](deployment/docs/EBAY-README.md) | eBay API integration, price lookup, and listing automation |
| [AVERY_94102_GUIDE.md](deployment/docs/AVERY_94102_GUIDE.md) | SKU label generation for physical inventory tracking |

### 📋 Reference
| Document | Purpose |
|----------|---------|
| [TO-DO.md](deployment/docs/TO-DO.md) | Roadmap, planned features, and AI automation plans |
| [SECRETS.md](deployment/docs/SECRETS.md) | Environment variable reference and credential management |

### 🔬 Technical Analysis (February 2026)
| Document | Purpose |
|----------|---------|
| [Analysis Documentation](deployment/docs/analysis/) | Multi-user implementation review, security fixes, and code quality assessment |

---

## Features

### 🌐 Web Application

**User & Account Management**
- Secure multi-user authentication system
- **Multi-user support** - Each user has separate items and optional eBay credentials
- User dashboard with account settings
- Password change functionality
- Session management with automatic invalidation

**Comic Inventory Management**
- Add, edit, browse, and delete comic listings
- Real-time field validation against marketplace requirements
- Duplicate SKU detection and prevention
- Smart pagination with lazy-loaded images
- Advanced search and filtering

**Image Management**
- Direct upload to AWS S3 with automatic processing
- WebP thumbnail generation for optimal performance
- Support for up to 8 images per listing
- SKU-specific image management
- Automatic color profile conversion

**Data Export & Reporting**
- Generate Whatnot-compatible CSV files for bulk import
- eBay File Exchange format export
- Automatic S3 backup of exports
- Filtered exports by listing type
- CSV history and recovery

**Marketplace Tools**
- Integrated eBay price lookup with sold listings search
- Market research and competitive analysis
- Automatic price suggestions
- eBay Marketplace Account Deletion endpoint (GDPR compliant)

**User Experience**
- Responsive, mobile-friendly design
- WCAG accessibility compliance with keyboard navigation
- Toast notifications for user feedback
- Skeleton loaders for smooth transitions
- Real-time character counters and auto-formatting
- Keyboard shortcuts (Ctrl+S, Ctrl+N, ESC)
- Unsaved changes warnings
- Empty state illustrations
- Dark mode support (configurable)

### 💻 Command-Line Interface

**Batch Processing**
- Process CSV files with automatic validation
- Batch upload images to S3 (up to 8 per comic)
- SKU generation with automatic tracking
- Fail-fast validation before any uploads

**Image Management**
- Bulk image upload with progress tracking
- Automatic retry logic with exponential backoff
- Selective deletion by SKU
- S3 bucket cleanup utilities

**Data Management**
- CSV import and export
- SKU reset and recovery
- Inventory backup and restore

### 🏷️ Label Printing

- Avery 94102 label template support
- Word mail merge integration
- Multiple layout options (simple, detailed, barcode)
- CSV export for label generation
- Batch label printing

---

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Backend Framework** | Flask | 3.0+ |
| **Language** | Python | 3.8+ |
| **Cloud Storage** | AWS S3 | - |
| **Image Processing** | Pillow (PIL) | Latest |
| **Frontend** | HTML5/CSS3/JavaScript | Modern |
| **Configuration** | python-dotenv | - |
| **Process Management** | Gunicorn + Supervisor | - |
| **Web Server** | Nginx | Latest |
| **Deployment** | Ansible | Latest |

---

## Prerequisites

### Required
- **Python 3.8** or higher
- **Git** for version control
- **AWS Account** with S3 bucket created
- **AWS IAM Credentials** (Access Key ID and Secret Access Key)
- **eBay Developer Account** (for price lookup feature)

### Optional (for deployment)
- **AWS Lightsail** VM (Ubuntu 22.04 LTS recommended)
- **Ansible** 2.9+ (for automated deployment)
- **Docker** (for containerized deployment)

---

## Installation

### Before You Begin

**Important:** If you plan to rename this application or deploy to production, first configure your app identity:

**File:** `deployment/group_vars/all.yml`

```yaml
app_name: app_item_listing_tool              # Change to your app name
app_display_name: "App Item Listing Tool"    # Change to your display name  
app_url: "https://github.com/yourusername/app_item_listing_tool"  # Your repo URL
```

See [deployment/DEPLOYMENT_PREP.md](deployment/DEPLOYMENT_PREP.md#application-configuration) for complete details.

---

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd app_item_listing_tool
```

### Step 2: Create Virtual Environment

```bash
# macOS/Linux
python3 -m venv .venv
source .venv/bin/activate

# Windows
python -m venv .venv
.venv\Scripts\activate
```

### Step 3: Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 4: Configure Environment Variables

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# === Flask Configuration ===
FLASK_ENV=development              # development or production
SECRET_KEY=your-random-secret-key  # Use: python -c "import secrets; print(secrets.token_hex(32))"
PORT=8000

# === Authentication ===
# Format: username:password,username2:password2
USERS=admin:change_me

# === AWS Configuration ===
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
S3_BUCKET=your-bucket-name
S3_FOLDER=production

# === eBay Configuration ===
EBAY_PRODUCTION_APP_ID=your_ebay_app_id
EBAY_PRODUCTION_CERT_ID=your_ebay_cert_id
EBAY_PRODUCTION_DEV_ID=your_ebay_dev_id
EBAY_PRODUCTION_TOKEN=your_ebay_token
EBAY_VERIFICATION_TOKEN=your_64_char_verification_token

# === Optional Settings ===
COMIC_IMAGE_PATH=instance/item_images
S3_KEY_PREFIX=images/
CLOUDFRONT_DOMAIN=your-cloudfront-domain.com
```

### Step 5: Initialize Directories

```bash
mkdir -p instance/{uploads,item_images,exports,images,snapshots,trash}
```

### Step 6: Verify Installation

```bash
# Test Flask app loads
python -c "from app import create_app; app = create_app('development'); print('✓ App configured successfully')"

# Start development server
python runapp.py
```

Visit `http://localhost:8000` and log in with your credentials.

---

## Usage

### Web Application

#### Starting the Server

```bash
# Development mode (with auto-reload)
FLASK_ENV=development python runapp.py

# Production mode (use Gunicorn in production)
gunicorn -w 4 -b 0.0.0.0:8000 runapp:app
```

The application is then available at `http://localhost:8000`

#### Main Features

| Feature | URL | Description |
|---------|-----|-------------|
| **Login** | `/login` | Authenticate to the system |
| **Dashboard** | `/` | Overview and quick actions |
| **Add Comic** | `/add` | Create new comic listing |
| **Browse Comics** | `/browse` | Search and view inventory |
| **Download CSV** | `/download` | Export to Whatnot format |
| **eBay Export** | `/download/ebay` | Export to eBay format |
| **Trash** | `/trash` | Recover deleted items |
| **Account** | `/account` | Manage user preferences |

#### Common Workflows

**Adding a Comic:**
1. Navigate to `/add`
2. Fill in title, description, and other required fields
3. Upload up to 8 images
4. Set pricing and listing preferences
5. Click "Save" (or Ctrl+S)

**Exporting to Whatnot:**
1. Go to `/browse`
2. Review and finalize all listings
3. Click "Download CSV" at `/download`
4. File downloads as `comics_export.csv`
5. Import to Whatnot seller dashboard

**Researching eBay Pricing:**
1. Open `/price-lookup` (if available)
2. Enter comic title or SKU
3. View sold listings and market trends
4. Compare competitor prices

### Command-Line Interface

#### Processing CSV Files

```bash
# Process CSV with images and upload to S3
python main.py path/to/input.csv

# The tool will:
# - Read and validate all rows
# - Generate SKUs for new items
# - Find local images in instance/item_images/comic{N}/
# - Upload images to S3
# - Create instance/items.csv with S3 URLs
```

#### Managing S3 Images

```bash
# Delete all images from S3 bucket (USE WITH CAUTION)
python main.py --s3delete

# This will:
# - Delete all files from your S3 bucket
# - Clear instance/items.csv
# - Reset your inventory
```

#### Image Organization

Organize images for batch processing:

```
instance/item_images/
├── comic1/
│   ├── front.jpg
│   ├── back.jpg
│   └── detail.jpg
├── comic2/
│   ├── front.jpg
│   └── back.jpg
└── comic3/
    └── cover.png
```

Each directory can contain up to 8 images. The CLI processes them in alphabetical order.

---

## Configuration

### Whatnot Field Validation

The application enforces the following Whatnot marketplace requirements:

| Field | Type | Requirements | Notes |
|-------|------|--------------|-------|
| **SKU** | String | Auto-generated, unique | Used for tracking |
| **Title** | String | Required, 80 chars max | Brief item description |
| **Description** | String | Required, no length limit | Detailed item information |
| **Category** | String | "Comics & Manga" only | Whatnot requirement |
| **Sub-Category** | String | Must be valid option | See Whatnot docs |
| **Condition** | String | New, Like New, Good, Fair, Poor | Specific allowed values |
| **Price** | Decimal | Minimum $1.00, whole dollars | No cents allowed |
| **Quantity** | Integer | Minimum 1 | Total items available |
| **Images** | URL | 1-8 per listing | S3 URLs required |

### Environment Variables Reference

See [SECRETS.md](deployment/docs/SECRETS.md) for complete reference and generation instructions.

---

## Project Structure

```
app_item_listing_tool/
│
├── 📁 app/                              # Flask application package
│   ├── models/                          # Data models
│   │   ├── comic.py                    # Comic listing model
│   │   ├── user.py                     # User authentication model
│   │   ├── trash_item.py               # Deleted item recovery model
│   │   └── snapshot.py                 # Backup snapshot model
│   │
│   ├── routes/                          # HTTP route handlers
│   │   ├── main.py                     # Page rendering routes
│   │   ├── api.py                      # JSON API endpoints
│   │   └── auth.py                     # Authentication handlers
│   │
│   ├── services/                        # Business logic layer
│   │   ├── comic_service.py            # Comic operations
│   │   ├── csv_service.py              # CSV import/export
│   │   ├── s3_service.py               # AWS S3 operations
│   │   ├── ebay_service.py             # eBay API integration
│   │   ├── snapshot_service.py         # Backup management
│   │   └── trash_service.py            # Trash/recovery operations
│   │
│   ├── utils/                           # Utility functions
│   │   ├── helpers.py                  # Common utilities
│   │   ├── whatnot_validators.py       # Whatnot validation rules
│   │   ├── ebay_validators.py          # eBay validation rules
│   │   └── sync_state.py               # Backup sync state
│   │
│   ├── templates/                       # HTML templates
│   │   ├── base.html                   # Base template layout
│   │   ├── index.html                  # Comic add/edit form
│   │   ├── comics_list.html            # Browse/search interface
│   │   ├── login.html                  # Login form
│   │   └── ...
│   │
│   ├── static/                          # Static assets
│   │   ├── css/                        # Stylesheets
│   │   ├── js/                         # JavaScript
│   │   ├── 404.html                    # Error pages
│   │   └── robots.txt                  # SEO configuration
│   │
│   ├── config.py                        # Flask configuration
│   └── __init__.py                      # Flask app factory
│
├── 📁 docs/                             # Documentation
│   ├── DEPLOYMENT.md                   # Automated deployment guide
│   ├── SECURITY.md                     # Security hardening
│   ├── EBAY-README.md                  # eBay integration guide
│   └── ...
│
├── 📁 deployment/                       # Deployment automation
│   ├── ansible.cfg                     # Ansible configuration
│   ├── site.yml                        # Ansible playbook
│   ├── files/                          # Configuration files
│   └── scripts/                        # Deployment scripts
│
├── 📁 instance/                         # Instance-specific data (gitignored)
│   ├── user_preferences.json          # Hashed user credentials
│   ├── items.csv                       # Comic inventory
│   ├── sku.txt                         # Current SKU counter
│   ├── uploads/                        # Temporary uploads
│   ├── images/                         # Local image cache
│   ├── snapshots/                      # Backup snapshots
│   ├── trash/                          # Deleted items
│   └── exports/                        # CSV exports
│
├── 📁 label_tools/                      # Label generation utilities
│   └── generate_avery_labels.py        # Avery label generator
│
├── main.py                              # CLI tool entry point
├── runapp.py                            # Web app entry point
├── requirements.txt                     # Python dependencies
├── .env.example                         # Environment template
├── .gitignore                           # Git ignore rules
├── README.md                            # This file
└── LICENSE                              # License terms
```

---

## AWS S3 Setup Guide

### 1. Create S3 Bucket

1. Log into [AWS Management Console](https://console.aws.amazon.com)
2. Navigate to S3 service
3. Click "Create bucket"
4. Enter a unique bucket name (e.g., `my-comics-inventory`)
5. Select region closest to you
6. Click "Create bucket"

### 2. Create IAM User with S3 Access

1. Navigate to IAM service
2. Click "Users" → "Create user"
3. Enter a username (e.g., `comics-app`)
4. Select "Programmatic access"
5. Click "Next: Permissions"
6. Attach policy: `AmazonS3FullAccess` (or create custom)
7. Complete user creation
8. Copy Access Key ID and Secret Access Key to `.env`

### 3. Configure S3 Bucket Policy (for public images)

In S3 bucket settings, add this bucket policy to allow public read access:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::your-bucket-name/*"
        }
    ]
}
```

### 4. Optional: Enable CloudFront CDN

For better performance with large image libraries:

1. Create CloudFront distribution pointing to S3 bucket
2. Set `CLOUDFRONT_DOMAIN` in `.env`
3. Configure custom domain (optional)
4. Set origin access identity for security

---

## Deployment

### Automated Deployment (Recommended)

Deploy to AWS Lightsail with one command:

```bash
# 1. Prepare your VM (Ubuntu 22.04 LTS)
# - Create Lightsail instance
# - Allow inbound ports 22 (SSH), 80 (HTTP), 443 (HTTPS)

# 2. Upload code
rsync -avz --exclude='.venv' --exclude='.git' --exclude='instance' \
  ./ ubuntu@<YOUR-IP>:/home/ubuntu/app_item_listing_tool/

# 3. Run deployment script
ssh ubuntu@<YOUR-IP>
cd /home/ubuntu/app_item_listing_tool/deployment
sudo bash deploy.sh
```

The deployment script automatically configures:
- ✅ Python 3 environment with virtual environment
- ✅ Nginx as reverse proxy with proper timeouts
- ✅ Gunicorn application server
- ✅ Supervisor for process management
- ✅ SSL/TLS certificates (Let's Encrypt)
- ✅ Firewall rules and security hardening
- ✅ Automatic backups to S3
- ✅ Log rotation and monitoring

See [docs/DEPLOYMENT.md](deployment/docs/DEPLOYMENT.md) for detailed instructions and options.

### Manual Deployment

For custom setups or non-Lightsail environments:

1. **Install System Dependencies**
   ```bash
   sudo apt update && sudo apt upgrade
   sudo apt install python3.10 python3.10-venv nginx supervisor
   ```

2. **Setup Application**
   ```bash
   cd /opt/app_item_listing_tool
   python3 -m venv .venv
   .venv/bin/pip install -r requirements.txt
   ```

3. **Configure Gunicorn**
   - Create systemd service or supervisor config
   - Set workers based on CPU count: `workers = (2 * cpu_count) + 1`
   - Configure logging and restart behavior

4. **Setup Nginx**
   - Configure reverse proxy to Gunicorn (port 8000)
   - Enable gzip compression for static assets
   - Set proper upload size limits (16MB+)

5. **Setup SSL/TLS**
   - Use Let's Encrypt for free SSL certificates
   - Auto-renew with certbot

6. **Configure Backups**
   - Setup daily S3 backups
   - Configure instance folder sync to S3
   - Test recovery procedures

See [docs/DEPLOYMENT-MANUAL.md](deployment/docs/DEPLOYMENT-MANUAL.md) for complete manual setup guide.

---

## Troubleshooting

### Common Issues & Solutions

#### Images Not Uploading to S3

**Symptoms:** Upload completes but images don't appear in S3

**Solutions:**
1. Verify AWS credentials in `.env`
   ```bash
   aws s3 ls --profile default
   ```
2. Check S3 bucket exists and is accessible
   ```bash
   aws s3 ls s3://your-bucket-name/
   ```
3. Verify IAM user has S3 permissions
4. Check bucket policy allows uploads
5. Review Flask error logs for details

#### CSV Validation Errors

**Symptoms:** "Validation failed" when importing CSV

**Solutions:**
1. Verify CSV column names match exactly (case-sensitive)
2. Check all required fields have values
3. Ensure field values meet requirements (e.g., price ≥ $1)
4. Review validation rules in `app/utils/whatnot_validators.py`
5. Check CSV encoding is UTF-8

#### Login Issues

**Symptoms:** Cannot log in even with correct credentials

**Solutions:**
1. Clear browser cookies and cache
2. Check `SECRET_KEY` is set in `.env`
3. Verify `USERS` format: `username:password,user2:pass2`
4. Check `users.json` file exists in `instance/`
5. Review Flask session configuration

#### SKU Issues

**Symptoms:** Duplicate SKUs or inconsistent numbering

**Solutions:**
1. Check `instance/sku.txt` is readable/writable
2. Verify file isn't corrupted
3. Reset to default: `echo "1000" > instance/sku.txt`
4. Check S3 backup has correct SKU
5. Restore from S3 if local is corrupted

#### Performance Issues

**Symptoms:** Slow image uploads, timeouts, or freezing

**Solutions:**
1. Check network connection speed
2. Verify S3 bucket is in same AWS region
3. Increase Flask timeout: `app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 300`
4. Enable CloudFront CDN for faster distribution
5. Check server disk space and memory

#### Database Errors (if using database)

**Symptoms:** Database connection failures

**Solutions:**
1. Verify database credentials in `.env`
2. Check database server is running
3. Verify network connectivity to database
4. Run database migrations if applicable
5. Check database user permissions

#### Missing Thumbnails

**Symptoms:** Images show as "No Image" or load slowly despite files existing

**Solutions:**
1. Run the thumbnail fix script:
   ```bash
   # Preview what would be fixed
   python fix_missing_thumbnails.py --dry-run
   
   # Generate missing thumbnails
   python fix_missing_thumbnails.py
   
   # Or use the helper script
   ./fix-thumbnails.sh --dry-run
   ```
2. Check `instance/images/` has write permissions
3. Verify Pillow is installed: `pip install Pillow`
4. See `FIX_THUMBNAILS_README.md` for detailed instructions

**When to use:**
- After manually adding images to `instance/images/`
- After restoring from backup without thumbnails
- When startup validation reports missing thumbnails
- Images exist but web interface shows placeholders

---

## Environment Variables Reference

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `FLASK_ENV` | string | No | `development` | Environment mode (development/production) |
| `SECRET_KEY` | string | Yes* | None | Flask session secret (32+ random chars) |
| `PORT` | integer | No | `8000` | Server port |
| `AWS_ACCESS_KEY_ID` | string | Yes | None | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | string | Yes | None | AWS IAM secret key |
| `AWS_REGION` | string | No | `us-east-1` | AWS region for S3 |
| `S3_BUCKET` | string | Yes | None | S3 bucket name for images |
| `S3_FOLDER` | string | No | `production` | S3 folder prefix |
| `EBAY_VERIFICATION_TOKEN` | string | Yes* | None | eBay verification token |
| `COMIC_IMAGE_PATH` | string | No | `instance/item_images` | Local image directory |
| `CLOUDFRONT_DOMAIN` | string | No | None | CloudFront domain for CDN |
| `APP_SECRET_TOKEN` | string | No | None | Secret token for APIs |

*Required for that specific feature

---

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes**: Write clear, descriptive commits
4. **Add tests**: Ensure new code is tested
5. **Update documentation**: Keep docs in sync with code
6. **Submit a pull request**: Reference related issues

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## Support & Help

Need assistance?

- 📧 **Issues**: [Create an issue](../../issues) on GitHub
- 📖 **Documentation**: Check [docs/](deployment/docs/) folder
- 🔍 **FAQ**: Common questions in [docs/TO-DO.md](deployment/docs/TO-DO.md)
- 💬 **Discussions**: Use GitHub Discussions for questions

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

---

## Acknowledgments

Built with ❤️ for comic book sellers and collectors managing inventory on Whatnot and eBay marketplaces.

**Key Technologies Used:**
- Flask for reliable web framework
- AWS S3 for scalable cloud storage
- Pillow for image processing
- Ansible for infrastructure automation

---

<div align="center">

**[⬆ Back to Top](#listing-app)**

Made with ❤️ | [View Docs](deployment/docs/) | [Report Issue](../../issues) | [Star us ⭐](../../)

</div>


## ✨ Features

### Web Application
- **User Authentication**: Secure login system with session management and user management dashboard
- **Comic Management**: Add, edit, browse, and delete comic listings with intuitive interface and duplicate SKU prevention
- **Image Upload**: Direct upload to AWS S3 with automatic thumbnail generation (WebP format) and SKU-specific image deletion
- **Real-time Validation**: Inline field validation against Whatnot requirements
- **CSV Export**: Generate Whatnot-compatible CSV files for bulk import with automatic S3 backup
- **eBay Price Lookup**: Integrated price research tool with sold listings and active item search
- **Account Management**: Change username and password from the dashboard
- **Smart Pagination**: Efficient browsing with lazy-loading images
- **Responsive Design**: Mobile-friendly interface with touch optimization
- **Accessibility**: WCAG-compliant with skip-to-content links and keyboard navigation
- **Marketplace Compliance**: eBay Marketplace Account Deletion endpoint for GDPR/compliance
- **Modern UX**:
  - Toast notifications for user feedback
  - Skeleton loaders for smooth loading states
  - Character counters and auto-formatting
  - Keyboard shortcuts (Ctrl+S to save, Ctrl+N for new, ESC to cancel, Left/Right arrows in edit mode)
  - Confirmation dialogs for destructive actions and unsaved changes warnings
  - Empty state illustrations
  - Visual enhancements: alternating row colors and smooth hover highlights

### CLI Tool
- **Batch Processing**: Process CSV files with automatic validation
- **Image Upload**: Batch upload comic images to S3 (up to 8 images per comic)
- **SKU Management**: Automatic SKU generation and tracking
- **S3 Management**: Bulk delete S3 images or targeted SKU-specific image deletion
- **Reliability**: Automatic retries for S3 operations and robots.txt AI bot blocking
- **Validation**: Pre-upload validation to catch errors before S3 upload

### Label Printing
- **SKU Label Templates**: Word mail merge templates for Avery labels
- **Label CSV Generator**: Extract SKU data from exports for printing
- **Multiple Layouts**: Simple, detailed, and barcode label formats
- **Easy Integration**: Generate labels directly from CSV exports

## Tech Stack

- **Backend**: Flask 3.0+ (Python web framework)
- **Cloud Storage**: AWS S3 (image hosting)
- **Image Processing**: Pillow (thumbnail generation)
- **Frontend**: HTML/CSS/JavaScript
- **Configuration**: python-dotenv (environment management)

## Prerequisites

- Python 3.8 or higher
- AWS Account with S3 bucket
- AWS IAM credentials (Access Key ID and Secret Access Key)
- eBay Developer Account (for price lookup feature)

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd app_item_listing_tool
```

### 2. Create Virtual Environment
```bash
python3 -m venv .venv
source .venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies
```bash
pip3 install -r requirements.txt
```

### 4. Configure Environment Variables
Create a `.env` file in the project root:
```bash
cp .env.example .env
```

Edit `.env` with your credentials:
```env
# Flask Configuration
FLASK_ENV=development
SECRET_KEY=change-this-to-a-random-secret-key
PORT=8000

# User Authentication
# Format: username:password,username2:password2

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_REGION=us-east-1
S3_BUCKET=your_bucket_name_here

# eBay API Configuration (for price lookup and marketplace compliance)
# Generate token: ./deployment/scripts/generate-ebay-token.sh
EBAY_VERIFICATION_TOKEN=your-64-character-token-here
```

### 5. Create Required Directories
```bash
mkdir -p instance/uploads
mkdir -p instance/item_images
```

## Usage

### Web Application

#### Start the Development Server
```bash
python runapp.py
```

The application will be available at `http://localhost:8000`

#### Features
1. **Login**: Use the authentication system to access the app
2. **Add Comics**: Navigate to `/add` to create new comic listings
3. **Browse Comics**: View all comics at `/browse` with pagination
4. **Export CSV**: Download Whatnot-compatible CSV from `/download`

### CLI Tool

#### Process CSV File
Process a CSV file with comic data and upload images:
```bash
python main.py input.csv
```

The CLI will:
1. Read and validate all rows in the CSV
2. Generate SKUs automatically
3. Find images in `instance/item_images/comic1/`, `instance/item_images/comic2/`, etc.
4. Upload images to S3 (up to 8 per comic)
5. Create `instance/whatnot_upload.csv` with S3 URLs

#### Delete All S3 Images
Remove all images from your S3 bucket:
```bash
python main.py --s3delete
```

⚠️ **Warning**: This will permanently delete all images in your S3 bucket!

## Project Structure

```
app_item_listing_tool/
├── app/                          # Flask application package
│   ├── models/                  # Data models
│   ├── routes/                  # Route handlers
│   ├── services/                # Business logic
│   ├── templates/               # HTML templates (responsive)
│   ├── utils/                   # Utility functions
│   └── static/                  # Static assets & error pages
├── docs/                        # Documentation
├── deployment/                  # Deployment automation (Ansible)
├── instance/                    # Instance-specific files (gitignored)
│   ├── user_preferences.json   # Hashed user credentials
│   ├── whatnot_upload.csv       # Generated export file
│   ├── sku.txt           # SKU tracker
│   ├── all_comic_delete/            # Full deletion backups
│   └── single_comic_delete/    # Individual comic backups
├── label_tools/                 # Label generation tools
├── main.py                     # CLI tool entry point
├── runapp.py                   # Web app entry point
├── requirements.txt            # Python dependencies
└── README.md                  # This file
```

## Whatnot Field Validation

The tool validates the following Whatnot fields:
- **SKU**: Automatically generated, tracked in `instance/sku.txt`
- **Title**: Required, max 80 characters
- **Category**: Must be valid Whatnot category
- **Description**: Required
- **Condition**: Predefined values (New, Like New, Good, Fair, Poor)
- **Price**: Numeric, minimum $1.00
- **Quantity**: Integer, minimum 1
- **Image URLs**: Up to 8 images per listing

## Image Management

### Directory Structure
For CLI batch processing, organize images as:
```
instance/item_images/
├── comic1/
│   ├── image1.jpg
│   ├── image2.jpg
│   └── ...
├── comic2/
│   ├── image1.jpg
│   └── ...
```

### Supported Formats
- JPG/JPEG
- PNG
- GIF
- WebP

### Image Processing
- Automatic thumbnail generation (configurable size)
- Upload to S3 with public URLs
- Maximum 8 images per comic listing

## AWS S3 Setup

### 1. Create S3 Bucket
1. Go to AWS S3 Console
2. Create a new bucket
3. Enable public access for images (or configure CloudFront)
4. Note the bucket name for `.env` configuration

### 2. Create IAM User
1. Go to AWS IAM Console
2. Create a new user with programmatic access
3. Attach policy: `AmazonS3FullAccess` (or create custom policy)
4. Save Access Key ID and Secret Access Key for `.env`

### 3. Configure Bucket Policy (Optional)
For public image access:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::your-bucket-name/*"
        }
    ]
}
```

## Development

### Running Tests
```bash
# Run specific test file
python test_auth.py
```

### Debug Mode
Set `FLASK_ENV=development` in `.env` to enable debug mode with auto-reload.

### Code Structure
- **Routes**: Handle HTTP requests and responses
- **Services**: Contain business logic and external integrations
- **Utils**: Shared utility functions and validators
- **Models**: Data structures (currently using CSV, can be extended to database)

## 🚀 Deployment

### Production Deployment

This project includes **automated deployment** to AWS EC2 with complete infrastructure provisioning.

**Prerequisites:**
1. Configure your app name in `deployment/group_vars/all.yml`:
   ```yaml
   app_name: app_item_listing_tool  # Change this to rename your app
   app_display_name: "App Item Listing Tool"
   app_url: "https://github.com/yourusername/app_item_listing_tool"
   ```

2. Create `deployment/secrets.env` with your credentials (see [deployment/DEPLOYMENT_PREP.md](deployment/DEPLOYMENT_PREP.md))

**One-Command Deploy:**
```bash
cd deployment
./scripts/infra-complete-setup.sh
```

This automatically creates:
- ✅ EC2 instance with IAM role (t3.nano/micro)
- ✅ VPC, security groups, networking
- ✅ S3 bucket for images
- ✅ AWS Secrets Manager for credentials
- ✅ CloudFront CDN with DDoS protection
- ✅ AWS WAF for security
- ✅ Complete application deployment

**Documentation:**
- **Full Guide**: [deployment/DEPLOYMENT_COMPLETE_GUIDE.md](deployment/DEPLOYMENT_COMPLETE_GUIDE.md)
- **Preparation**: [deployment/DEPLOYMENT_PREP.md](deployment/DEPLOYMENT_PREP.md)
- **Operations**: [deployment/OPERATIONS.md](deployment/OPERATIONS.md)
- **Security**: [docs/SECURITY.md](deployment/docs/SECURITY.md)

### Manual Production Setup
If not using the automated deployment:

1. Set `FLASK_ENV=production` in `.env`
2. Use a strong `SECRET_KEY` (32+ random characters)
3. Configure production WSGI server (Gunicorn recommended)
4. Set up reverse proxy (Nginx/Apache)
5. Configure process manager (Supervisor/systemd)
6. Set up SSL/TLS (Let's Encrypt recommended)

## Troubleshooting

### Images Not Uploading
- Check AWS credentials in `.env`
- Verify S3 bucket exists and is accessible
- Check bucket permissions/policy

### Validation Errors
- Review `app/utils/validators.py` for field requirements
- Check CSV field names match exactly
- Ensure all required fields have values

### SKU Issues
- Delete `instance/sku.txt` to reset SKU counter
- Check file permissions on instance directory

### Session/Login Issues
- Clear browser cookies
- Check `SECRET_KEY` is set in `.env`
- Verify Flask session configuration

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FLASK_ENV` | No | Environment (development/production) |
| `SECRET_KEY` | Yes | Flask secret key for sessions |
| `PORT` | No | Port to run the app (default: 8000) |
| `AWS_ACCESS_KEY_ID` | Yes | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | Yes | AWS IAM secret key |
| `AWS_REGION` | No | AWS region (default: us-east-1) |
| `S3_BUCKET` | Yes | S3 bucket name for images |
| `EBAY_VERIFICATION_TOKEN` | Yes* | eBay verification token (32-80 chars) for marketplace account deletion endpoint. Auto-generated on deployment. |
| `COMIC_IMAGE_PATH` | No | Path to comic images (default: instance/item_images) |
| `S3_KEY_PREFIX` | No | S3 key prefix (default: images/) |

*Required for eBay Developer Portal compliance. Generate with: `./deployment/scripts/generate-ebay-token.sh`

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

## Support

For issues and questions:
- Create an issue in the repository
- Check existing documentation in `docs/` folder.
- Review validation rules in `app/utils/validators.py`

## Acknowledgments

Built with ❤️ for comic book sellers and collectors managing inventory on Whatnot and eBay marketplaces.

**Key Technologies Used:**
- Flask for reliable web framework
- AWS S3 for scalable cloud storage
- Pillow for image processing
- Ansible for infrastructure automation

---

<div align="center">

**[⬆ Back to Top](#listing-app)**

Made with ❤️ | [View Docs](deployment/docs/) | [Report Issue](../../issues) | [Star us ⭐](../../)

</div>
