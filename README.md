# Comic Inventory Management Application

> A Flask web application for managing comic book inventory with AWS S3 storage, marketplace exports, and eBay price research.

[![Python 3.8+](https://img.shields.io/badge/Python-3.8%2B-blue)](https://www.python.org/downloads/)
[![Flask 3.0+](https://img.shields.io/badge/Flask-3.0%2B-green)](https://flask.palletsprojects.com/)

---

## What Is This?

A complete inventory management system for comic book sellers. Manage your catalog, upload images to the cloud, export to marketplaces (Whatnot/eBay), research pricing, and generate SKU labels.

**Key Features:**
- 📋 Catalog comics with images and marketplace-ready descriptions
- 📤 Cloud storage (AWS S3) with automatic image processing
- 📊 Export CSV files for bulk marketplace uploads (Whatnot/eBay)
- 💰 eBay price research and market analysis
- 🏷️ SKU label generation for physical inventory
- 🗑️ Trash/recovery system for deleted items
- 👥 Multi-user support with individual accounts

---

## Requirements

**This is NOT a standalone application.** It requires AWS cloud services.

### Must Have
- ✅ **AWS Account** with S3 bucket
- ✅ **IAM Credentials** (Access Key ID + Secret Access Key)
- ✅ **Python 3.8+** for local development

### Optional
- ⚙️ **eBay Developer Account** - For price lookup features
- ⚙️ **Production Server** - AWS EC2/Lightsail for deployment
- ⚙️ **Custom Domain** - For branded production URL

**Monthly Cost:** ~$5-10/month (S3 storage + small server)

---

## Quick Local Setup

For local development only (production deployment is different):

```bash
# 1. Clone repository
git clone https://github.com/yourusername/your_app_name.git
cd your_app_name
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Configure (copy .env.example to .env and add your credentials)
cp .env.example .env
# Edit .env with AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_BUCKET

# 3. Create directories
mkdir -p instance/{uploads,item_images,images,exports,snapshots,trash}

# 4. Run locally
python runapp.py
```

Access at `http://localhost:8000`

**Want to deploy to production?** → See [deployment/DEPLOYMENT_COMPLETE_GUIDE.md](deployment/DEPLOYMENT_COMPLETE_GUIDE.md)

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Web Browser (User Interface)                       │
└─────────────────┬───────────────────────────────────┘
                  │ HTTP/HTTPS
┌─────────────────┴───────────────────────────────────┐
│  Flask Application (Python)                         │
│  ├── Routes (URL handlers)                          │
│  ├── Services (Business logic)                      │
│  ├── Models (Data structures)                       │
│  └── Templates (HTML/CSS/JS)                        │
└─────────────────┬────────────────┬──────────────────┘
                  │                │
        ┌─────────┴─────┐   ┌──────┴──────┐
        │ Local Storage │   │   AWS S3    │
        │  (CSV files)  │   │  (Images)   │
        └───────────────┘   └─────────────┘
```

**Storage:**
- **CSV Files** - Inventory data (no database needed)
- **AWS S3** - Product images with automatic processing
- **JSON Files** - User preferences and settings

**No database required** - Simple CSV-based storage for easy portability.

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Backend** | Flask 3.0+ (Python 3.8+) |
| **Storage** | CSV files (local), AWS S3 (images) |
| **Image Processing** | Pillow (WebP thumbnails) |
| **Frontend** | HTML5/CSS3/JavaScript |
| **Deployment** | Ansible, Nginx, Gunicorn, Systemd |
| **Security** | Multi-user auth, dedicated app user, systemd hardening |

---

## How to Use

### Web Interface

| Feature | URL | Description |
|---------|-----|-------------|
| **Add Comic** | `/add` | Create new listings with images |
| **Browse** | `/browse` | Search and view inventory |
| **Export** | `/download` | Generate Whatnot/eBay CSV |
| **Price Lookup** | `/price-lookup` | eBay market research |
| **Trash** | `/trash` | Recover deleted items |
| **Account** | `/account` | User settings |

### Command-Line Interface

```bash
# Batch process CSV files
python main.py input.csv

# Manage S3 images
python main.py --s3delete
```

See [deployment/docs/CLI.md](deployment/docs/CLI.md) for CLI documentation.

---

## Project Structure

```
your_app_name/
├── app/                     # Flask application
│   ├── models/             # Data models (Comic, User)
│   ├── routes/             # URL handlers
│   ├── services/           # Business logic (S3, CSV, eBay)
│   ├── templates/          # HTML templates
│   └── static/             # CSS, JS, images
│
├── deployment/             # Deployment automation & docs
│   ├── playbooks/         # Ansible playbooks
│   ├── scripts/           # Deployment scripts
│   ├── group_vars/        # Configuration
│   └── *.md               # Deployment documentation
│
├── instance/              # Data storage (gitignored)
│   ├── items.csv         # Inventory data
│   ├── user_preferences.json
│   ├── images/           # Local image cache
│   └── snapshots/        # Backups
│
├── main.py               # CLI tool
├── runapp.py             # Web server entry point
└── requirements.txt      # Python dependencies
```

---

## Documentation

### Getting Started
- **[Quick Local Setup](#quick-local-setup)** - Run locally for development
- **[deployment/DEPLOYMENT_PREP.md](deployment/DEPLOYMENT_PREP.md)** - Prerequisites and configuration
- **[deployment/DEPLOYMENT_COMPLETE_GUIDE.md](deployment/DEPLOYMENT_COMPLETE_GUIDE.md)** - Full production deployment

### Operations & Usage
- **[deployment/OPERATIONS.md](deployment/OPERATIONS.md)** - Day-to-day operations, monitoring, troubleshooting
- **[deployment/MULTI_USER_SUPPORT.md](deployment/MULTI_USER_SUPPORT.md)** - Adding users, managing accounts
- **[deployment/SECRET_MANAGEMENT.md](deployment/SECRET_MANAGEMENT.md)** - Managing credentials and secrets

### Security & Technical
- **[deployment/SECURITY_HARDENING.md](deployment/SECURITY_HARDENING.md)** - Security architecture and hardening
- **[deployment/PRE_DEPLOYMENT_CHECKLIST.md](deployment/PRE_DEPLOYMENT_CHECKLIST.md)** - Pre-deployment verification
- **[app/SECURITY.md](app/SECURITY.md)** - Application-level security details

### Integration Guides
- **[deployment/docs/EBAY-README.md](deployment/docs/EBAY-README.md)** - eBay API integration
- **[deployment/docs/AWS-SSM-SECRETS.md](deployment/docs/AWS-SSM-SECRETS.md)** - AWS secrets management

---

## Development

### Local Development Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Run with auto-reload
FLASK_ENV=development python runapp.py

# Access at http://localhost:8000
```

### Environment Variables

Create `.env` file (copy from `.env.example`):

```env
# Required
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET=your-bucket-name
USERS=username:password
SECRET_KEY=random-secret-here

# Optional (have defaults)
AWS_REGION=us-east-1
FLASK_ENV=development
PORT=8000
```

See [deployment/DEPLOYMENT_PREP.md](deployment/DEPLOYMENT_PREP.md) for complete configuration guide.

---

## Troubleshooting

**Common issues and solutions:**

### Images not uploading to S3
- Check AWS credentials in `.env`
- Verify S3 bucket exists and IAM user has permissions
- Check logs: `tail -f instance/*.log`

### Can't login
- Verify `USERS` format: `username:password`
- Check `SECRET_KEY` is set
- Clear browser cookies

### CSV validation errors
- Column names are case-sensitive
- Check required fields have values
- Prices must be ≥ $1.00

**More help:** See [deployment/OPERATIONS.md](deployment/OPERATIONS.md#troubleshooting)

---

## Production Deployment

**Ready to deploy to a server?**

📖 **See [deployment/DEPLOYMENT_COMPLETE_GUIDE.md](deployment/DEPLOYMENT_COMPLETE_GUIDE.md)**

The deployment guide covers:
- ✅ AWS account setup (S3, IAM, EC2)
- ✅ One-command automated deployment
- ✅ SSL certificates and custom domains
- ✅ Security hardening (dedicated user, systemd hardening)
- ✅ Monitoring and backups
- ✅ Troubleshooting and operations

**Quick deploy (after configuration):**
```bash
cd deployment
./scripts/infra-complete-setup.sh
```

---

## Features (Detailed)

<details>
<summary><b>Click to expand full feature list</b></summary>

### Web Application
- Multi-user authentication with password management
- Add/edit/delete comic listings with real-time validation
- Image upload (up to 8 per comic) with S3 integration
- WebP thumbnail generation for performance
- Advanced search and filtering
- CSV export for Whatnot and eBay bulk uploads
- eBay price research (sold listings, market trends)
- Trash/recovery system for deleted items
- Responsive mobile-friendly design
- Keyboard shortcuts (Ctrl+S save, Ctrl+N new, ESC cancel)
- Toast notifications and loading states

### Command-Line Interface
- Batch process CSV files with validation
- Bulk image upload to S3
- Automatic SKU generation and tracking
- S3 bucket management and cleanup

### Label Printing
- Avery 94102 label template support
- SKU label generation for physical inventory
- CSV export for Word mail merge

### Security
- Dedicated application user (no SSH access)
- 20+ systemd security hardening features
- Session management with auto-logout
- Password hashing with Werkzeug
- Input validation and sanitization

</details>

---

## Support

- 📖 **Documentation:** [deployment/](deployment/) folder
- 🐛 **Issues:** [GitHub Issues](../../issues)
- 💬 **Questions:** [GitHub Discussions](../../discussions)

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made for comic book sellers** 📚

[⬆ Back to Top](#comic-inventory-management-application)

</div>
