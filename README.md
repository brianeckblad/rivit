# dockyard

A Flask application for managing comic book inventory with AWS S3 storage, marketplace exports, and eBay price research.

---

## What It Does

Manage a comic book catalog, upload images to the cloud, export to marketplaces (WhatNot/eBay), research pricing, and generate SKU labels.

- Catalog comics with images and marketplace-ready descriptions
- Cloud storage (AWS S3) with automatic image processing and thumbnail generation
- Image proxy — browser fetches all images through the app; S3 bucket stays private
- Export CSV files for bulk marketplace uploads (WhatNot/eBay)
- eBay price research and market analysis
- SKU label generation for physical inventory
- Trash/recovery system for deleted items
- Multi-user support with individual accounts

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| Python 3.10+ | Required |
| AWS account (S3 + Secrets Manager + IAM) | Needed for cloud storage and secret management |
| eBay Developer account | Optional — needed for eBay price research and listing |

---

## Local Development

```bash
git clone https://github.com/brianeckblad/dockyard.git
cd dockyard
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
S3_BUCKET=dockyard-adequate-app
USERS=username:password
SECRET_KEY=random-secret-here
```

For production, all configuration comes from AWS Secrets Manager. See [Chapter 7: Secret Management](deployment/docs/guides/SECRET_MANAGEMENT.md).

---

## Deployment

Ansible playbooks for AWS EC2 deployment are in `deployment/`. See the [deployment guide](deployment/docs/README.md) for full details.

### Quick deploy

```bash
cd deployment
source scripts/load-vars.sh   # writes literal connection values to inventories/hosts.yml

# Step 1: Create AWS resources (S3, IAM policies, Secrets Manager)
ansible-playbook playbooks/provision-app.yml --vault-password-file ~/.vault_pass

# Step 2: Deploy application to server (code, nginx, supervisor, SSL)
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass

# Update (pull new code and restart)
ansible-playbook playbooks/update.yml --vault-password-file ~/.vault_pass
```

### SSH access management

`update.yml` and `security-hardening.yml` both include an automatic pre-flight that whitelists `admin_ip` on port 22 in the EC2 security group before connecting. To manage SSH access explicitly:

```bash
ansible-playbook playbooks/open-ssh.yml --vault-password-file ~/.vault_pass
```

Requires `admin_ip` and `ec2_ssh_security_group_id` in `group_vars/vault.yml`.

---

## Architecture

```
Browser
  │
  ▼
Flask app (gunicorn · nginx · supervisor)
  ├── Routes ──── URL handlers
  ├── Services ── Business logic (S3, CSV, eBay)
  ├── Models ──── Data structures
  └── Templates ─ HTML/CSS/JS
  │            │
  ▼            ▼
Local        AWS S3 (private bucket)
(CSV)       (Images via proxy)
```

| Component | Technology |
|-----------|-----------|
| Backend | Flask 3.0+ (Python 3.10+) |
| Storage | CSV files (local), AWS S3 (images), AWS Secrets Manager (secrets) |
| Image processing | Pillow (WebP thumbnails) |
| Frontend | HTML5, CSS3, JavaScript |
| Process manager | Supervisor + Gunicorn |
| Web server | Nginx (SSL, rate limiting, security headers) |
| Intrusion prevention | fail2ban (SSH + nginx jails, admin IP excluded) |

No database required. CSV-based storage for portability.

---

## Configuration (vault.yml)

All secrets and server configuration live in `deployment/group_vars/vault.yml` (Ansible vault encrypted).

### Key variables

| Variable | Description | Example |
|----------|-------------|---------|
| `app_name` | Short technical identifier | `dockyard` |
| `server_host` | EC2 instance IP | `18.222.15.210` |
| `server_admin_user` | OS user for SSH (pre-existing on server) | `ubuntu` |
| `app_deploy_user` | AWS IAM deployer user | `dockyard-deployer` |
| `app_runtime_user` | Per-app OS user that runs gunicorn | `dockyard_runtime` |
| `admin_ip` | Your public IP — whitelisted in EC2 SG and fail2ban | `98.38.38.147` |
| `ec2_ssh_security_group_id` | EC2 security group ID for SSH rules | `sg-0a69da9d10235b811` |
| `s3_bucket_name` | S3 bucket (globally unique) | `dockyard-adequate-app` |

Copy the template to get started:

```bash
cp deployment/group_vars/vault.yml.example deployment/group_vars/vault.yml
# edit vault.yml, then:
ansible-vault encrypt deployment/group_vars/vault.yml --vault-password-file ~/.vault_pass
```

---

## Web Interface

| Feature | URL |
|---------|-----|
| Dashboard / landing | `/` |
| Add comic | `/add` |
| Browse inventory | `/browse` |
| Export CSV | `/download` |
| Price lookup | `/price-lookup` |
| Trash | `/trash` |
| Account | `/account` |

---

## Project Structure

```
dockyard/
├── app/
│   ├── models/              Data models (Comic, User)
│   ├── routes/              URL handlers
│   ├── services/            Business logic (S3, CSV, eBay)
│   ├── templates/           HTML templates
│   └── static/              CSS, JS, images
├── deployment/
│   ├── playbooks/           Ansible playbooks
│   ├── docs/                Deployment guide (13 chapters)
│   ├── templates/           Jinja2 templates (nginx, supervisor, fail2ban)
│   └── group_vars/          Vault config (encrypted)
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
| Images not loading | Check S3 bucket name in vault matches `S3_BUCKET` in Secrets Manager; verify IAM role has `s3:GetObject` |
| Cannot log in | Verify `USERS` format is `username:password`; check `SECRET_KEY` is set; clear cookies |
| SSH port 22 timeout | Run `ansible-playbook playbooks/open-ssh.yml --vault-password-file ~/.vault_pass` to re-whitelist your IP |
| SSL certificate failure | Confirm DNS A record for `server_name` points to `server_host`; then run `setup-ssl.yml` |
| `server_admin_user is undefined` | Run `source scripts/load-vars.sh` — it writes literal values to `inventories/hosts.yml` |
| CSV validation errors | Column names are case-sensitive; prices must be >= $1.00 |

See [Chapter 5: Operations — Troubleshooting](deployment/docs/guides/OPERATIONS.md#troubleshooting) for more.

---

## License

MIT License. See [LICENSE](LICENSE).
