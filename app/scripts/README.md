# Application Utility Scripts

**Location:** `app/scripts/`

These are application-level utility scripts for data maintenance, validation, and tooling. They operate on application data (images, CSVs, labels) and are NOT part of deployment.

For deployment and operational scripts, see `deployment/scripts/`.

---

## Scripts

### `util-check-comic-images.py`
**Purpose:** Verify comic images exist and are valid

### `util-fix-missing-thumbnails.py`
**Purpose:** Regenerate missing thumbnail images

### `util-generate-page-images.py`
**Purpose:** Generate page images from source files

### `util-validate-csv-schema.py`
**Purpose:** Validate CSV data files against expected schema

### `util-generate-ebay-token.sh`
**Purpose:** Generate eBay verification token for Marketplace Account Deletion endpoint

### `generate_avery_labels.py`
**Purpose:** Generate printable Avery label sheets (SKU labels)

---

## Usage

These scripts are run manually when needed, either locally or on the server:

```bash
# Run locally
python app/scripts/util-validate-csv-schema.py

# Run on server
ssh user@server
cd /{app_name}
python app/scripts/util-fix-missing-thumbnails.py
```

---

## Script Locations

| Location | Purpose |
|----------|---------|
| `app/scripts/` | Application data utilities (this directory) |
| `deployment/scripts/` | Deployment, configuration, and operational scripts |
