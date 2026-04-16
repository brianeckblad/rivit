#!/usr/bin/env python3
"""Fix comics whose Description field contains leaked eBay HTML template markup.

Run on the server:
    cd /home/ubuntu/rampe
    source .venv/bin/activate
    python app/scripts/fix_html_in_descriptions.py

What it does:
    1. Reads the CSV
    2. Finds rows where Description contains HTML tags (<div>, <li>, <strong>)
    3. Strips all HTML, leaving only the plain text
    4. Writes the cleaned CSV back
    5. Reports what was changed
"""
import csv
import os
import re
import shutil
from datetime import datetime

# Resolve paths relative to project root
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
CSV_PATH = os.path.join(PROJECT_ROOT, 'instance', 'data', 'brian', 'items.csv')

# Fallback to instance/items.csv for local dev
if not os.path.exists(CSV_PATH):
    CSV_PATH = os.path.join(PROJECT_ROOT, 'instance', 'items.csv')

if not os.path.exists(CSV_PATH):
    print(f"ERROR: CSV not found at {CSV_PATH}")
    exit(1)


def strip_html(text):
    """Remove HTML tags and collapse whitespace."""
    cleaned = re.sub(r'<[^>]+>', ' ', text)
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned


def has_html(text):
    """Check if text contains HTML markup."""
    return bool(text and ('<div>' in text or '<li>' in text or '<strong>' in text or '<ul>' in text))


def main():
    print(f"Reading CSV: {CSV_PATH}")

    # Backup first
    backup_path = CSV_PATH + f'.backup-{datetime.now().strftime("%Y%m%d-%H%M%S")}'
    shutil.copy2(CSV_PATH, backup_path)
    print(f"Backup saved: {backup_path}")

    # Read all rows
    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    fixed_count = 0
    for row in rows:
        desc = row.get('Description', '')
        if has_html(desc):
            original = desc
            cleaned = strip_html(desc)
            row['Description'] = cleaned
            sku = row.get('SKU', '?')
            print(f"\nSKU {sku}:")
            print(f"  BEFORE ({len(original)} chars): {original[:120]}...")
            print(f"  AFTER  ({len(cleaned)} chars): {cleaned[:120]}")
            fixed_count += 1

    if fixed_count == 0:
        print("\nNo HTML found in any Description fields. Nothing to fix.")
        os.remove(backup_path)
        return

    # Write cleaned CSV
    with open(CSV_PATH, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nFixed {fixed_count} row(s). CSV updated.")
    print(f"Backup at: {backup_path}")


if __name__ == '__main__':
    main()

