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

## Quick Start

### For Deployment to Production

**👉 Start here:** [deployment/docs/guides/PREREQUISITES.md](deployment/docs/guides/PREREQUISITES.md)

Then choose your deployment method:
- **Fast (15 min):** [deployment/docs/guides/QUICKSTART.md](deployment/docs/guides/QUICKSTART.md)
- **Detailed (1-2 hours):** [deployment/docs/guides/MANUAL_DEPLOYMENT.md](deployment/docs/guides/MANUAL_DEPLOYMENT.md)
- **Infrastructure only:** [deployment/docs/guides/INFRASTRUCTURE.md](deployment/docs/guides/INFRASTRUCTURE.md)

### For Local Development

```bash
# Clone and setup
git clone https://github.com/yourusername/rampe.git
cd rampe
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Configure (optional, for local testing with AWS)
cp .env.example .env
nano .env  # Add your AWS credentials

# Create directories
mkdir -p instance/{uploads,item_images,images,exports,snapshots,trash}

# Run locally
python runapp.py
```

Access at `http://localhost:8000`

---

## Requirements

**This is NOT a standalone application.** It requires AWS cloud services.

### To Deploy to Production
- ✅ **AWS Account** with S3 bucket and EC2
- ✅ **AWS CLI** configured with credentials  
- ✅ **Ansible** for deployment automation
- ✅ **Python 3.8+** on your local machine
- ⚙️ **eBay Developer Account** (optional, for price lookup)

### To Run Locally  
- ✅ **Python 3.8+**
- ✅ **pip** for dependencies
- ⚙️ **AWS Account** (optional, needed for S3 access)

**Monthly Cost:** ~$5-10/month (S3 storage + small EC2 instance on free tier)

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

---

## Project Structure

```
rampe/
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
│   ├── group_vars/        # Configuration templates
│   ├── docs/              # Deployment guides
│   └── README.md          # Deployment overview
│
├── instance/              # Data storage (gitignored)
│   ├── items.csv         # Inventory data
│   ├── user_preferences.json
│   ├── images/           # Local image cache
│   └── snapshots/        # Backups
│
├── main.py               # CLI tool
├── runapp.py             # Web server entry point
├── README.md             # This file
└── requirements.txt      # Python dependencies
```

---

## Deployment Documentation

### Prerequisites & Setup
- **[PREREQUISITES.md](deployment/docs/guides/PREREQUISITES.md)** - AWS account, CLI, and configuration setup (30 min)

### Deployment Methods

| Method | Best For | Time | Link |
|--------|----------|------|------|
| **Automated (QUICKSTART)** | Fast production deployment | 15-20 min | [QUICKSTART.md](deployment/docs/guides/QUICKSTART.md) |
| **Manual (Step-by-step)** | Learning, understanding details | 1-2 hours | [MANUAL_DEPLOYMENT.md](deployment/docs/guides/MANUAL_DEPLOYMENT.md) |
| **Infrastructure Only** | AWS resources without app | 15 min | [INFRASTRUCTURE.md](deployment/docs/guides/INFRASTRUCTURE.md) |

### After Deployment

| Task | Guide | Time |
|------|-------|------|
| **Update Application Code** | [UPDATING_APPLICATION.md](deployment/docs/guides/UPDATING_APPLICATION.md) | 1-10 min |
| **Daily Operations** | [OPERATIONS.md](deployment/docs/guides/OPERATIONS.md) | Reference |
| **Monitor & Alert** | [MONITORING.md](deployment/docs/guides/MONITORING.md) | 10 min |
| **Add Users** | [MULTI_USER.md](deployment/docs/guides/MULTI_USER.md) | 5 min |
| **Manage Secrets** | [SECRET_MANAGEMENT.md](deployment/docs/guides/SECRET_MANAGEMENT.md) | Reference |

### Advanced Configuration

| Topic | Guide |
|-------|-------|
| **CloudFront CDN** | [CLOUDFRONT_CDN.md](deployment/docs/guides/CLOUDFRONT_CDN.md) |
| **WAF & Security** | [WAF_CONFIGURATION.md](deployment/docs/guides/WAF_CONFIGURATION.md) |
| **Security Hardening** | [SECURITY_HARDENING.md](deployment/docs/guides/SECURITY_HARDENING.md) |
| **Architecture & Design** | [ARCHITECTURE.md](deployment/docs/reference/ARCHITECTURE.md) |

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

For **local testing only**, create `.env` file (copy from `.env.example`):

```env
# Required for local S3 access
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET=your-bucket-name
USERS=username:password
SECRET_KEY=random-secret-here

# Optional (have defaults)
AWS_REGION=us-east-2
FLASK_ENV=development
PORT=8000
```

**For production:** All configuration comes from AWS Secrets Manager. See [SECRET_MANAGEMENT.md](deployment/docs/guides/SECRET_MANAGEMENT.md) for details.

---

## Troubleshooting

**Common issues and solutions:**

### Images not uploading to S3
- Check AWS credentials
- Verify S3 bucket exists and has proper permissions
- Check logs: `tail -f instance/*.log`

### Can't login
- Verify `USERS` format: `username:password`
- Check `SECRET_KEY` is set
- Clear browser cookies

### CSV validation errors
- Column names are case-sensitive
- Check required fields have values
- Prices must be ≥ $1.00

**More help:** See [OPERATIONS.md - Troubleshooting](deployment/docs/guides/OPERATIONS.md#troubleshooting)

---

## Next Steps

### Ready to Deploy?

1. **Read:** [deployment/docs/guides/PREREQUISITES.md](deployment/docs/guides/PREREQUISITES.md) (30 min)
2. **Choose:** [QUICKSTART.md](deployment/docs/guides/QUICKSTART.md) or [MANUAL_DEPLOYMENT.md](deployment/docs/guides/MANUAL_DEPLOYMENT.md)
3. **Deploy:** Follow your chosen guide
4. **Operate:** See [OPERATIONS.md](deployment/docs/guides/OPERATIONS.md) for daily tasks

### Want to Learn More?

- **Architecture:** [docs/reference/ARCHITECTURE.md](deployment/docs/reference/ARCHITECTURE.md)
- **Security:** [SECURITY_HARDENING.md](deployment/docs/guides/SECURITY_HARDENING.md)
- **Operations:** [OPERATIONS.md](deployment/docs/guides/OPERATIONS.md)

---

## Support

- 📖 **Documentation:** [deployment/](deployment/) folder and guides above
- 🐛 **Issues:** Check troubleshooting guides first
- 💬 **Questions:** See appropriate deployment guide for your scenario

---

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made for comic book sellers** 📚

[⬆ Back to Top](#comic-inventory-management-application)

</div>

