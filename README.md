# rivit

A Flask application for managing comic book inventory with AWS S3 storage, marketplace exports, and eBay price research.

---

## What It Does

Manage a comic book catalog, upload images to the cloud, export to marketplaces (Whatnot/eBay), research pricing, and generate SKU labels.

- Catalog comics with images and marketplace-ready descriptions
- Cloud storage (AWS S3) with automatic image processing
- Export CSV files for bulk marketplace uploads (Whatnot/eBay)
- eBay price research and market analysis
- SKU label generation for physical inventory
- Trash/recovery system for deleted items
- Multi-user support with individual accounts

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| Python 3.8+ | Required |
| AWS account (S3) | Optional — needed for cloud image storage |
| eBay Developer account | Optional — needed for eBay price research |

---

## Local Development

```bash
git clone https://github.com/yourusername/rivit.git
cd rivit
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

mkdir -p instance/{uploads,item_images,images,exports,snapshots,trash}

python runapp.py
```

Access at `http://localhost:8000`.

For S3 access during local development, create a `.env` file:

```env
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET=your-bucket-name
USERS=username:password
SECRET_KEY=random-secret-here
```

For production, all configuration comes from AWS Secrets Manager. See [Chapter 7: Secret Management](deployment/docs/guides/SECRET_MANAGEMENT.md).

---

## Deployment

Ansible playbooks for AWS EC2 deployment are in `deployment/`. See the [deployment guide](deployment/docs/README.md) for details.

---

## Architecture

```
Browser
  │
  ▼
Flask app
  ├── Routes ──── URL handlers
  ├── Services ── Business logic (S3, CSV, eBay)
  ├── Models ──── Data structures
  └── Templates ─ HTML/CSS/JS
  │           │
  ▼           ▼
Local        AWS S3
(CSV)       (Images)
```

| Component | Technology |
|-----------|-----------|
| Backend | Flask 3.0+ (Python 3.8+) |
| Storage | CSV files (local), AWS S3 (images), JSON (settings) |
| Image processing | Pillow (WebP thumbnails) |
| Frontend | HTML5, CSS3, JavaScript |

No database required. CSV-based storage for portability.

---

## Usage

### Web Interface

| Feature | URL |
|---------|-----|
| Add comic | `/add` |
| Browse inventory | `/browse` |
| Export CSV | `/download` |
| Price lookup | `/price-lookup` |
| Trash | `/trash` |
| Account | `/account` |

### Command Line

```bash
python main.py input.csv          # Batch process CSV
python main.py --s3delete         # Manage S3 images
```

---

## Project Structure

```
rivit/
├── app/
│   ├── models/              Data models (Comic, User)
│   ├── routes/              URL handlers
│   ├── services/            Business logic (S3, CSV, eBay)
│   ├── templates/           HTML templates
│   └── static/              CSS, JS, images
├── deployment/
│   ├── playbooks/           Ansible playbooks
│   ├── docs/                Deployment guide (13 chapters)
│   └── group_vars/          Configuration templates
├── instance/                Data storage (gitignored)
│   ├── items.csv            Inventory data
│   └── snapshots/           Backups
├── main.py                  CLI tool
├── runapp.py                Web server entry point
└── requirements.txt         Python dependencies
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Images not uploading to S3 | Check AWS credentials; verify bucket exists and has proper permissions |
| Cannot log in | Verify `USERS` format is `username:password`; check `SECRET_KEY` is set; clear cookies |
| CSV validation errors | Column names are case-sensitive; prices must be >= $1.00 |

See [Chapter 5: Operations — Troubleshooting](deployment/docs/guides/OPERATIONS.md#troubleshooting) for more.

---

## License

MIT License. See [LICENSE](LICENSE).
