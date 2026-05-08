# Application Architecture Reference

A complete blueprint of the Python/Flask web application — its structure, data
flow, startup sequence, security model, and extension points. Use this document
to replicate the same application architecture in a new project.

> Replace every `{app_name}` placeholder with your application name.
> All runtime configuration comes from AWS Secrets Manager (production) or a
> `.env` file (local development) — never hard-coded.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Technology Stack](#technology-stack)
3. [Application Structure](#application-structure)
4. [Entry Points](#entry-points)
5. [Blueprint and Route Layout](#blueprint-and-route-layout)
6. [Service Layer](#service-layer)
7. [Data Storage Model](#data-storage-model)
8. [Multi-User Isolation](#multi-user-isolation)
9. [Authentication and Authorization](#authentication-and-authorization)
10. [Security Middleware](#security-middleware)
11. [Startup Sequence](#startup-sequence)
12. [Configuration and Secrets](#configuration-and-secrets)
13. [Logging](#logging)
14. [Frontend Design System](#frontend-design-system)
15. [Key Patterns and Conventions](#key-patterns-and-conventions)
16. [Local Development Setup](#local-development-setup)

---

## Architecture Overview

```
Browser
  │
  ▼
Nginx (SSL termination, static files, rate limiting)
  │
  ▼
Gunicorn WSGI server (4 workers, 127.0.0.1:8000)
  │
  ▼
Flask Application  ──── app factory: create_app()
  │
  ├── auth_bp      /login, /logout
  ├── main_bp      / landing, /add, /browse, /account, /price-lookup, …
  └── api_bp       /api/**  (67 routes across 11 domain modules)
        │
        ├── Services (business logic)
        │     ├── comic_service      — item CRUD orchestration
        │     ├── csv_service        — file-locked CSV read/write
        │     ├── s3_service         — S3 images, backups, sync
        │     ├── ebay_service       — eBay Trading API integration
        │     ├── snapshot_service   — manual backup/restore
        │     ├── trash_service      — soft-delete with 30-day TTL
        │     ├── health_check_service — CSV ↔ S3 image consistency
        │     ├── cloudwatch_service — custom metrics publishing
        │     ├── sns_service        — alert delivery
        │     ├── user_secrets_service — per-user eBay tokens
        │     └── analytics_service  — click heatmap analytics
        │
        └── Storage
              ├── CSV files          — inventory per user
              ├── JSON files         — preferences, settings
              └── S3 bucket          — images, exports, backups
```

---

## Technology Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Language | Python 3.10+ | No database — CSV + JSON + S3 only |
| Web framework | Flask 3.0+ | App factory pattern; Blueprints for route isolation |
| WSGI server | Gunicorn 21+ | 4 sync workers; `127.0.0.1:8000` |
| Reverse proxy | Nginx | SSL termination, static files, rate limiting |
| Process manager | Systemd / Supervisor | Manages Gunicorn lifecycle |
| Object storage | AWS S3 | Images, exports, CSV backups, user prefs |
| Secrets | AWS Secrets Manager | Runtime secrets; `.env` fallback for local dev |
| Metrics / logs | AWS CloudWatch | Log shipping + custom metrics |
| Alerting | AWS SNS | Email/SMS on CloudWatch alarms |
| Frontend | Jinja2 + vanilla JS | No JS framework; all interactions via `fetch()` |
| CSS | Custom design tokens | `tokens.css` + `components.css` shared system |
| Image processing | Pillow | Upload validation, WebP thumbnail generation |
| File locking | `filelock` | Prevents CSV corruption under concurrent writes |
| eBay integration | eBay Trading API (XML) | Search, list, revise, end listings |

---

## Application Structure

```
app/
├── __init__.py             # App factory (create_app), logging, startup sync,
│                           # background thread, blueprint registration
├── config.py               # Config classes (Dev/Prod), get_secret() helper
├── security.py             # IP blocklist, rate limiting, attack detection
│
├── models/                 # Plain dataclasses — no ORM
│   ├── comic.py            # Comic dataclass + field definitions
│   ├── user.py             # UserManager: login, preferences, JSON storage
│   ├── snapshot.py         # Snapshot metadata dataclass
│   ├── trash_item.py       # TrashItem dataclass
│   └── analytics.py        # AnalyticsStore: heatmap event persistence
│
├── routes/
│   ├── auth.py             # login_required, csrf_required, sync_not_locked decorators
│   │                       # + /login and /logout routes
│   ├── main.py             # Page routes (10 HTML pages, CSV export/download)
│   └── api/                # REST API — 11 modules, 67 routes, all under /api
│       ├── __init__.py
│       ├── comics.py       # Item CRUD (11 routes)
│       ├── ebay.py         # eBay listing actions (10 routes)
│       ├── ebay_listings.py # Account-level listing management (3 routes)
│       ├── ebay_search.py  # Price lookup / sold search (4 routes)
│       ├── ebay_taxonomy.py # Category / item aspect lookup (4 routes)
│       ├── account.py      # User account management (13 routes)
│       ├── snapshots.py    # Backup and restore (4 routes)
│       ├── trash.py        # Soft-delete management (3 routes)
│       ├── system.py       # Health, stats, disk (6 routes)
│       ├── analytics.py    # Click heatmap events (1 route)
│       └── admin.py        # Admin settings (8 routes)
│
├── services/               # All business logic lives here — routes call services
│   ├── comic_service.py    # ComicService: CRUD orchestration for items
│   ├── csv_service.py      # CSVService: file-locked reads/writes, header init
│   ├── s3_service.py       # S3Service: upload, thumbnail, sync, restore
│   ├── ebay_service.py     # EbayService: Trading API calls, payload sanitization
│   ├── snapshot_service.py # SnapshotService: point-in-time S3 backups
│   ├── trash_service.py    # TrashService: soft-delete, 30-day retention
│   ├── health_check_service.py # CSV ↔ S3 orphan detection and cleanup
│   ├── cloudwatch_service.py   # CloudWatch metrics publishing
│   ├── sns_service.py          # SNS notifications
│   ├── user_secrets_service.py # Per-user eBay tokens in Secrets Manager
│   └── analytics_service.py   # Heatmap event aggregation
│
├── utils/                  # Shared helpers — no business logic
│   ├── user_context.py     # Multi-user path resolution (ALWAYS use these)
│   ├── logging_utils.py    # safe_error_message(), logger helpers
│   ├── helpers.py          # CSRF tokens, filename generation, directory size
│   ├── csv_sanitizer.py    # CSV injection prevention (= + - @ prefixes)
│   ├── upload_security.py  # Image upload validation (Pillow verify + size cap)
│   ├── mass_deletion_protection.py # Safety circuit breakers
│   ├── monitoring.py       # @monitor_endpoint CloudWatch decorator
│   ├── sync_state.py       # Thread-safe singleton for S3 sync progress
│   ├── ebay_helpers.py     # eBay description parsing helpers
│   ├── ebay_validators.py  # eBay CSV export field definitions
│   ├── whatnot_validators.py # WhatNot CSV export field definitions
│   └── defaults_helpers.py # User preference defaults
│
├── scripts/                # Utility / maintenance scripts (not production routes)
│   ├── util_check_comic_images.py
│   ├── util_fix_missing_thumbnails.py
│   ├── util_generate_page_images.py   # Auto-generates analytics mockup PNGs
│   ├── util_migrate_csv_schema.py
│   └── util_validate_csv_schema.py
│
├── templates/              # Jinja2 HTML templates
│   ├── base.html           # Base layout: nav, CSS/JS links, modal skeleton
│   ├── landing.html        # Dashboard / home page
│   ├── comics_list.html    # Browse / inventory grid + list view
│   ├── index.html          # Add / Edit comic form
│   ├── add_from_image.html # AI-assisted add from image
│   ├── price_lookup.html   # eBay sold price lookup tool
│   ├── ebay_listings.html  # eBay account listings manager
│   ├── account.html        # User settings and preferences
│   ├── analytics_dashboard.html # Click heatmap analytics
│   ├── trash.html          # Soft-deleted items
│   ├── login.html          # Login page
│   └── ebay_description_template.html # eBay description builder
│
└── static/
    ├── css/
    │   ├── tokens.css      # Design tokens — ALL colors, spacing, radii
    │   └── components.css  # Shared component classes (.btn, .modal, etc.)
    ├── favicon/
    ├── analytics/          # Auto-generated page mockup PNGs
    ├── 404.html / 500.html / 502.html / 503.html
    └── placeholder.png
```

---

## Entry Points

### `runapp.py` — Web Server

```python
from app import create_app

app = create_app('production')   # or 'development'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
```

Gunicorn targets `runapp:app`. The `create_app()` factory performs all
initialization — blueprints, logging, startup sync, background threads.

### `main.py` — CLI Tool

Standalone batch processor for CSV operations and S3 image management.
Not used by the web server. Useful for one-off migrations or data fixes.

---

## Blueprint and Route Layout

Three blueprints are registered in `create_app()`:

| Blueprint | Prefix | Purpose |
|-----------|--------|---------|
| `auth_bp` | (root) | `/login`, `/logout` |
| `main_bp` | (root) | Page routes — all return HTML |
| `api_bp` | `/api` | REST API — all return JSON |

### Page routes (`main_bp`)

| URL | Template | Notes |
|-----|----------|-------|
| `/` | `landing.html` | Dashboard |
| `/add` | `index.html` | Add / edit item form |
| `/add-from-image` | `add_from_image.html` | Image-assisted add |
| `/browse` | `comics_list.html` | Inventory grid/list |
| `/price-lookup` | `price_lookup.html` | eBay price lookup |
| `/ebay-listings` | `ebay_listings.html` | eBay account listings |
| `/account` | `account.html` | User settings |
| `/analytics` | `analytics_dashboard.html` | Heatmap analytics |
| `/trash` | `trash.html` | Soft-deleted items |
| `/download` | — | CSV export (Content-Disposition attachment) |

### API routes (`api_bp`) — summary

| Module | Route prefix | Key operations |
|--------|-------------|---------------|
| `comics.py` | `/api/comic/` | Get, create, update, delete, upload image |
| `ebay.py` | `/api/comic/<sku>/ebay/` | List, update, end, relist eBay item |
| `ebay_listings.py` | `/api/ebay/listings/` | Fetch account listings, sync status |
| `ebay_search.py` | `/api/ebay/search/` | Sold price lookup, image search |
| `ebay_taxonomy.py` | `/api/ebay/taxonomy/` | Category suggestions, item aspects |
| `account.py` | `/api/account/` | Preferences, credentials, password |
| `snapshots.py` | `/api/snapshots/` | Create, list, restore, delete backups |
| `trash.py` | `/api/trash/` | List, restore, purge soft-deletes |
| `system.py` | `/api/system/` | Health, stats, disk usage, sync status |
| `analytics.py` | `/api/analytics/` | Record click events |
| `admin.py` | `/api/admin/` | IP blocklist, rate limits, security config |

---

## Service Layer

Services are **module-level singletons** — import and use directly; do not
re-instantiate in routes.

```python
# Correct — use the module-level instance
from app.services.comic_service import comic_service
from app.services.s3_service import s3_service
from app.services.ebay_service import ebay_service
```

### Key service responsibilities

**`ComicService`** (`comic_service.py`)
- Orchestrates item CRUD: read from CSV, write via `csv_service`, sync to S3
- Generates sequential SKUs from a per-user `sku.txt` counter
- Constructs thumbnail keys and manages image associations

**`CSVService`** (`csv_service.py`)
- Single writer for all CSV mutations — acquires a `filelock` before writing
- Initializes CSV with schema headers if not present
- Sanitizes all cell values through `csv_sanitizer.py` (CSV injection prevention)
- Never call `open(csv_path, 'w')` directly from routes — always go through this service

**`S3Service`** (`s3_service.py`)
- Uploads images (full + WebP thumbnail), exports, and CSV backups to S3
- Bi-directional sync: `sync_images_from_s3()`, `sync_exports_from_s3()`
- Restores CSV, SKU, and user preferences on startup
- Generates time-limited pre-signed URLs for downloads

**`EbayService`** (`ebay_service.py`)
- Wraps eBay Trading API XML calls (AddFixedPriceItem, ReviseFixedPriceItem, EndItem)
- Auto-sanitizes XML payloads via `_sanitize_trading_payload_strings()` — escapes bare `&`
- Caches category taxonomy locally in `instance/ebay_category_cache.json`
- Manages per-user tokens via `user_secrets_service`

**`SnapshotService`** (`snapshot_service.py`)
- Creates on-demand point-in-time S3 snapshots (CSV + images)
- Lists, restores, and deletes named snapshots

**`TrashService`** (`trash_service.py`)
- Soft-deletes items to `instance/data/{username}/trash/recent/`
- Auto-expires items older than 30 days
- Expiry cleanup runs on startup for all registered users

**`HealthCheckService`** (`health_check_service.py`)
- Runs after every startup S3 sync
- Detects orphaned S3 image keys (in S3 but not in CSV)
- Detects orphaned local images (on disk but not in CSV)
- Deletes confirmed orphans in both locations

---

## Data Storage Model

This application uses **no database**. All persistent state is in files.

### Per-user data layout

```
instance/
├── user_preferences.json      # All users' credentials + preferences (synced to S3)
├── app_defaults.json          # Application-level defaults
├── ebay_category_cache.json   # eBay taxonomy cache (shared, not per-user)
│
└── data/
    └── {username}/
        ├── items.csv          # Inventory — one row per item
        ├── sku.txt            # Sequential SKU counter (integer)
        ├── images/            # Full-resolution images
        ├── exports/           # Generated CSV exports (WhatNot, eBay)
        ├── snapshots/         # Named point-in-time backups
        └── trash/
            └── recent/        # Soft-deleted items (30-day TTL)
```

### CSV schema

`items.csv` is the canonical data store. Every row is one item (a comic).
Fields include: `sku`, `title`, `issue`, `publisher`, `grade`, `price`,
`condition`, `description`, `image_url`, `thumbnail_url`, `ebay_item_id`,
`ebay_status`, `ebay_price`, `ebay_schedule_time`, `whatnot_listed`, and
platform-specific export fields.

All CSV writes go through `CSVService` — never raw `open()`:
```python
csv_service.update_comic(csv_path, sku, updated_fields)
csv_service.delete_comic(csv_path, sku)
```

### S3 key structure

```
{s3_bucket_name}/
└── {s3_folder}/               # e.g. "production"
    └── {username}/
        ├── items.csv
        ├── sku.txt
        ├── user_preferences.json
        ├── images/
        │   ├── {sku}.jpg
        │   └── {sku}_thumb.webp
        ├── exports/
        └── snapshots/
```

### `user_preferences.json` schema

```json
{
  "{username}": {
    "password_hash": "...",
    "created_at": "ISO-8601",
    "preferences": {
      "default_view": "grid",
      "theme": "dark"
    },
    "ebay_credentials": "stored-in-secrets-manager"
  }
}
```

---

## Multi-User Isolation

Each user has their own subdirectory. **All path construction must go through
`app/utils/user_context.py`** — never hand-craft paths with
`f"instance/data/{username}/..."` in routes or services.

### `user_context.py` helpers

```python
from app.utils.user_context import (
    get_current_username,    # reads session['username']
    get_user_csv_file,       # → Path("instance/data/{u}/items.csv")
    get_user_sku_file,       # → Path("instance/data/{u}/sku.txt")
    get_user_image_dir,      # → Path("instance/data/{u}/images/")
    get_user_exports_dir,    # → Path("instance/data/{u}/exports/")
    get_user_trash_dir,      # → Path("instance/data/{u}/trash/")
    get_user_snapshots_dir,  # → Path("instance/data/{u}/snapshots/")
    get_user_analytics_dir,  # → Path("instance/data/{u}/analytics/")
    migrate_legacy_user_files,  # one-time migration for pre-multi-user installs
)
```

### Authorization rule

Username for access decisions always comes from the server-side session:

```python
username = session['username']   # CORRECT
username = request.args.get('username')  # NEVER — attackable
```

---

## Authentication and Authorization

Authentication is session-based. Sessions are invalidated on app restart
(development config uses `os.urandom(24)` as `SECRET_KEY`; production reads
from Secrets Manager, keeping sessions valid across restarts).

### Decorators (defined in `app/routes/auth.py`)

| Decorator | Effect |
|-----------|--------|
| `@login_required` | Redirects unauthenticated requests to `/login` |
| `@csrf_required` | Validates CSRF token on POST/PUT/PATCH/DELETE requests |
| `@sync_not_locked` | Returns 503 while S3 sync is in progress |
| `@disk_space_required` | Returns 507 if disk is below minimum threshold |

Every page route carries `@login_required`. Every state-changing API route
carries both `@login_required` and `@csrf_required`.

### CSRF flow

1. `generate_csrf_token()` in `app/utils/helpers.py` creates a token stored in
   the session and injected into every template via a Jinja2 global.
2. All state-changing JS calls include the token in the request headers:
   ```javascript
   headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content }
   ```
3. `@csrf_required` validates the header value against `session['csrf_token']`.

---

## Security Middleware

`app/security.py` installs a `before_request` hook that runs on every request.

### Layers

| Layer | Mechanism |
|-------|----------|
| IP blocklist | In-memory + disk-persisted `blocked_ips.json`; auto-expires |
| Rate limiting | Per-IP sliding window counters (in-memory) |
| Attack detection | Regex patterns for `.env`, SQL injection, path traversal, RCE probes |
| Auto-banning | IPs that trigger attack patterns are auto-blocked (configurable duration) |
| Security headers | Added to every response: `X-Frame-Options`, `X-Content-Type-Options`, `HSTS` |

Auto-ban thresholds and rate limits are configurable via the admin API
(`/api/admin/`).

---

## Startup Sequence

`create_app()` executes these steps synchronously before returning the app:

```
1. Load configuration (Config class, get_secret())
2. Configure logging (app.log, service.log, cleanup.log)
3. Initialize security middleware (before_request hook)
4. Ensure required directories exist
5. Migrate legacy flat-file user data (one-time, idempotent)
6. Sync user_preferences.json with S3 (timestamp-based, newest wins)
7. Initialize UserManager (load users into memory)
8. Per registered user:
   a. Sync SKU counter (highest wins between local and S3)
   b. Sync items.csv (newest wins; size-safety check prevents overwrite with empty)
   c. Initialize CSV headers if file is new
9. Cleanup expired trash items (all users)
10. Start background thread → sync images + exports from S3 → health check
11. Register blueprints (auth_bp, main_bp, api_bp)
12. Register Jinja2 globals (csrf_token)
13. Initialize eBay listings cache + category cache
14. Install before_request cache-expiry hook (1-hour eBay cache TTL)
15. Per-user CSV health check (log warning if count < 5)
16. Auto-regenerate analytics mockup PNGs if generation script changed
```

The background thread (step 10) uses a cross-worker lock (`sync_state`) so that
only one Gunicorn worker runs the sync, even when all four start simultaneously.

---

## Configuration and Secrets

### Config classes

| Class | env | `DEBUG` | `SECRET_KEY` |
|-------|-----|---------|-------------|
| `DevelopmentConfig` | `development` | `True` | Fresh random on each restart (clears sessions) |
| `ProductionConfig` | `production` | `False` | Must be set in Secrets Manager (startup validation) |

### `get_secret(key, default=None)`

Three-tier lookup in `app/config.py`:

```
AWS Secrets Manager  →  environment variable  →  default
```

In production the app reads all secrets from Secrets Manager via the EC2
instance IAM role — no static credentials on disk. In local development, a
`.env` file generated from the Ansible vault is used as the environment
variable tier.

### Key config values consumed

| Key | Purpose |
|-----|---------|
| `SECRET_KEY` | Flask session signing |
| `S3_BUCKET_NAME` | S3 bucket for all object storage |
| `S3_FOLDER` | Top-level S3 prefix (e.g. `production`) |
| `AWS_REGION` | AWS region for all SDK calls |
| `CLOUDFRONT_DOMAIN` | Optional CDN domain for image URLs |
| `SNS_TOPIC_ARN` | Optional alert delivery |
| `EBAY_PRODUCTION_APP_ID` / `CERT_ID` / `DEV_ID` / `TOKEN` | eBay API credentials |
| `APP_NAME` | App identity injected into logs and metric namespaces |

---

## Logging

Three dedicated rotating-file loggers, each capped at 10 MB × 10 rotations:

| Logger | Attribute | File | Content |
|--------|-----------|------|---------|
| Main app | `app.logger` | `app.log` | Request lifecycle, auth events, startup |
| Service | `app.service_logger` | `service.log` | S3 sync, health checks, background jobs |
| Cleanup | `app.cleanup_logger` | `cleanup.log` | Trash expiry, orphan deletion |

All loggers use a `UserContextFilter` that injects the current username into
every log record from request context.

In production, `ERROR`+ messages are additionally written to `error.log`.
All log files are shipped to CloudWatch by the CloudWatch agent.

### Logging utilities

`app/utils/logging_utils.py` exports:

- `safe_error_message(exc)` — returns a generic string for client responses
  in production; full detail always goes to the logger only. **Use this in
  every `jsonify` error response** — never `str(e)`.
- `get_service_logger()` — returns `logging.getLogger('service')`
- `get_cleanup_logger()` — returns `logging.getLogger('cleanup')`

---

## Frontend Design System

All visual styling is controlled by two shared CSS files loaded in `base.html`.

### `app/static/css/tokens.css`

Single source of truth for the entire color palette, spacing scale, typography,
border radii, and shadow tokens. All template styles reference these:

```css
/* example usage in any template */
.my-card {
    background: var(--color-elevated);
    color: var(--color-text);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
}
```

Key tokens:

| Token | Value | Role |
|-------|-------|------|
| `--color-bg` | `#1B1A1B` | App background |
| `--color-surface` | `#242223` | Top/bottom bars |
| `--color-elevated` | `#2D2B2C` | Cards, modals |
| `--color-inset` | `#171616` | Input fields |
| `--color-accent` | `#E2E800` | Primary highlight (bright yellow) |
| `--color-accent-2` | `#5C9EB8` | Secondary accent (steel blue) |
| `--color-danger` | `#C45C5C` | Destructive actions |
| `--color-text` | `#E8E8E6` | Primary text |
| `--color-text-muted` | `#C5C2BE` | Secondary text |

### `app/static/css/components.css`

Shared component classes used across all templates:

| Group | Classes |
|-------|---------|
| Buttons | `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-danger`, `.btn-sm` |
| Modals | `.modal`, `.modal-content`, `.modal-header`, `.modal-body`, `.close-btn` |
| Forms | `.form-group`, `.form-label`, `.form-input`, `.form-select` |
| Cards | `.card`, `.stat-card` |
| Layout | `.page-header`, `.page-controls-row`, `.action-section`, `.footer-bar` |
| Feedback | `.notification`, `.section-label` |

**Never re-declare these classes in template `<style>` blocks.** Page-specific
styles exist only in `{% block extra_css %}` for layout unique to that page.

### Template inheritance

All pages extend `base.html`:

```jinja2
{% extends "base.html" %}

{% block title %}Page Title{% endblock %}
{% block extra_css %} {# page-specific layout only #} {% endblock %}
{% block content %} {# page body #} {% endblock %}
{% block extra_js %} {# page-specific scripts #} {% endblock %}
```

`base.html` provides: navigation, `tokens.css`, `components.css`, CSRF meta tag,
Escape-to-close modal behaviour, and the global modal stack.

---

## Key Patterns and Conventions

### 1 — All API routes return JSON

```python
return jsonify({'success': True, 'data': result}), 200
return jsonify({'error': safe_error_message(e)}), 500
```

Never `str(e)` in responses — use `safe_error_message()`.

### 2 — Service singletons, not re-instantiation

```python
# ✓ correct
from app.services.csv_service import csv_service

# ✗ wrong
service = CSVService()
```

### 3 — User context for all paths

```python
# ✓ correct
from app.utils.user_context import get_user_csv_file
csv_path = get_user_csv_file(username)

# ✗ wrong
csv_path = f"instance/data/{username}/items.csv"
```

### 4 — Image upload security pattern

```python
from app.utils.upload_security import validate_uploaded_image
from werkzeug.utils import secure_filename

ext = validate_uploaded_image(request.files['image'])  # raises 400/413 on bad input
filename = f"{sku}.{ext}"  # generated, never user-supplied
```

### 5 — eBay payload sanitization

```python
# ✓ correct — sanitizer runs automatically
ebay_service.add_fixed_price_item(payload)

# ✗ wrong — manual escaping on top of automatic sanitization
title = comic['title'].replace('&', '&amp;')
```

### 6 — JavaScript confirm flow (snapshot → try → finally)

```javascript
async function confirmAction() {
    const sku = pendingItem.sku;       // snapshot state first
    try {
        await executeAction(sku);      // executor takes args, not globals
    } finally {
        pendingItem = { sku: null };   // always reset, even on error
    }
}
```

### 7 — Version injection

The `inject_version()` context processor in `create_app()` reads
`instance/app_version` (written by the deploy playbook), then falls back to
`git rev-list --count HEAD`. Every template gets `app_version` and
`app_version_display` automatically.

---

## Local Development Setup

```bash
# 1. Clone and create virtual environment
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 2. Generate .env from Ansible vault (requires ansible-vault + ~/.vault_pass)
cd deployment && python scripts/local_dev_setup_env.py && cd ..

# 3. Or create .env manually for a new project:
cat > .env << 'EOF'
SECRET_KEY=dev-secret-key-local
S3_BUCKET_NAME=your-bucket-name
S3_FOLDER=development
AWS_REGION=us-east-2
EBAY_PRODUCTION_APP_ID=
EBAY_PRODUCTION_CERT_ID=
EBAY_PRODUCTION_DEV_ID=
EBAY_PRODUCTION_TOKEN=
EOF

# 4. Run the development server
FLASK_ENV=development python runapp.py    # http://localhost:8000
```

### Dev vs production differences

| Aspect | Development | Production |
|--------|------------|-----------|
| `DEBUG` | `True` | `False` |
| `SECRET_KEY` | Fresh random on each restart | Fixed; from Secrets Manager |
| Log destination | `instance/app.log` + console | `/var/log/{app_name}/*.log` + CloudWatch |
| Secrets | `.env` file | AWS Secrets Manager via IAM role |
| S3 access | Uses explicit key/secret from `.env` (optional) | IAM instance profile (no keys) |
| `SESSION_COOKIE_SECURE` | `False` | `True` (or opt-out with `ALLOW_INSECURE_COOKIES=1`) |
| S3 sync | Optional (set `SKIP_S3_SYNC=1` to disable) | Always runs on startup |

