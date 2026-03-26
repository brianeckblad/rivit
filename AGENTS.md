# Agent Operational Guidelines

**Instructions for AI agents working on this project**

> **Auto-loaded rules:** The critical rules from this file are also in
> [`.github/copilot-instructions.md`](.github/copilot-instructions.md),
> which GitHub Copilot reads automatically at the start of every session.

---

## Project Context

- **Stack:** Python 3.8+ / Flask 3.0+ web application
- **Storage:** CSV files (inventory), AWS S3 (images), JSON (settings/preferences) — no database
- **Deployment:** Ansible playbooks to AWS EC2 (Ubuntu 22.04), Gunicorn + Nginx + Systemd
- **Shell:** zsh on macOS (development)
- **Secrets:** AWS Secrets Manager in production; `.env` file for local dev (generated from vault)
- **Deployment config:** `deployment/group_vars/vault.yml` (Ansible-vault encrypted, contains all variables)
- **Vault access:** `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass`
- **S3 bucket name:** Comes from `s3_bucket_name` in vault (not derived from `app_name`)
- **No tests:** The project has no test suite. There is no CI/CD pipeline.

---

## Architecture

### Entry points

| Entry | Purpose |
|-------|---------|
| `runapp.py` | Web server (Flask app via `create_app()` factory) |
| `main.py` | CLI tool for batch CSV processing, S3 image management |

### Application structure

```
app/
├── __init__.py          # App factory (create_app), logging, S3 sync on startup
├── config.py            # Config classes (Dev/Prod), secrets from AWS Secrets Manager
├── security.py          # IP blocklist, rate limiting, attack detection middleware
├── models/              # Dataclasses (Comic, User, Snapshot, TrashItem, Analytics)
│   └── user.py          # UserManager: auth, credentials, preferences (JSON file)
├── routes/
│   ├── auth.py          # login_required, csrf_required, sync_not_locked decorators
│   ├── main.py          # Page routes (landing, browse, add, download, price-lookup, account, ebay-listings, analytics)
│   └── api/             # 11 API modules (67 routes), registered on api_bp at /api
├── services/            # Business logic layer
│   ├── comic_service.py # Comic CRUD orchestration (user-specific CSV + SKU)
│   ├── csv_service.py   # CSV read/write with file locking
│   ├── s3_service.py    # S3 uploads, thumbnails (WebP), sync, restore
│   ├── ebay_service.py  # eBay API integration (search, listings, taxonomy)
│   ├── snapshot_service.py  # Manual backup/restore to S3
│   ├── trash_service.py     # Soft-delete with 30-day retention
│   ├── health_check_service.py  # CSV ↔ S3 image consistency checks
│   ├── cloudwatch_service.py    # CloudWatch metrics
│   ├── sns_service.py           # SNS notifications
│   ├── user_secrets_service.py  # Per-user eBay credentials in Secrets Manager
│   └── analytics_service.py     # Click heatmap analytics
├── scripts/             # App-level utility scripts (image checks, CSV validation, labels)
├── utils/               # Helpers, validators, logging, monitoring decorators
│   ├── user_context.py  # Multi-user file path resolution (CSV, SKU, S3, trash, exports)
│   ├── logging_utils.py # Service/cleanup/app logger helpers
│   ├── mass_deletion_protection.py  # Safety circuit breakers
│   ├── whatnot_validators.py        # CSV field validation rules
│   ├── ebay_validators.py          # eBay CSV export field definitions
│   ├── ebay_helpers.py             # eBay description parsing helpers
│   ├── defaults_helpers.py         # User preferences and app defaults
│   ├── helpers.py                  # Filename generation, CSRF tokens, directory size
│   ├── monitoring.py               # CloudWatch @monitor_endpoint decorator
│   └── sync_state.py              # Thread-safe singleton for S3 sync progress
├── templates/           # Jinja2 HTML templates (10 pages)
└── static/              # CSS, JS, images, error pages
```

### Key patterns

- **App factory:** `create_app(config_name)` in `app/__init__.py` — handles config, logging, security, S3 sync, blueprint registration.
- **Blueprints:** Three blueprints — `auth_bp`, `main_bp`, `api_bp` (mounted at `/api`). API routes split into 11 domain modules in `app/routes/api/`.
- **Service singletons:** Most services are module-level instances (`s3_service`, `comic_service`, `ebay_service`). Import and use directly; do not re-instantiate.
- **Multi-user isolation:** Each user gets their own CSV (`instance/data/{username}-items.csv`), SKU counter, snapshots, trash, exports, and images directory. Use `app/utils/user_context.py` helpers.
- **Secret precedence:** AWS Secrets Manager → environment variable → default value (see `get_secret()` in `config.py`).
- **Logging:** Three dedicated loggers — `app.logger` (app.log), `service` (service.log), `cleanup` (cleanup.log). Use helpers from `app/utils/logging_utils.py`.
- **Authentication:** Session-based via `login_required` decorator in `app/routes/auth.py`. Sessions invalidated on app restart. Additional decorators: `csrf_required`, `sync_not_locked`, `disk_space_required`.
- **User management:** `UserManager` in `app/models/user.py` — credentials and preferences stored in `instance/user_preferences.json`, synced to S3.
- **Startup sync:** On boot, the app factory syncs SKU (highest-wins), CSV inventory, and user preferences between local files and S3. Images/exports sync in a background thread, followed by a health check.
- **Version injection:** `inject_version()` context processor reads `instance/app_version` (set by deploy), falls back to `git rev-list --count HEAD`.

### Local development

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# Generate .env from vault (requires ansible-vault):
cd deployment && python scripts/local_dev_setup_env.py && cd ..
# Or create .env manually (see README.md)
python runapp.py   # http://localhost:8000
```

### Deployment commands

```bash
cd deployment
source scripts/load-vars.sh
ansible-playbook playbooks/provision-infrastructure.yml --vault-password-file ~/.vault_pass
ansible-playbook playbooks/setup-server.yml --vault-password-file ~/.vault_pass
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass
# Update existing deployment:
ansible-playbook playbooks/update.yml --vault-password-file ~/.vault_pass
```

---

## Shell Command Safety - CRITICAL

### Problem
Commands containing `{{ }}` (Jinja2), nested quotes, or heredocs cause the terminal to hang
waiting for input (`dquote>`, `heredoc>`, `quote>`). The agent cannot type interactively,
so the session freezes and the user must Ctrl-C to recover.

### Rule: Never Output Jinja2 Braces Through the Terminal

The zsh shell interprets `{{ }}` as glob patterns. Any command that outputs Jinja2 content
through the shell will hang or produce empty output.

```bash
# BAD - shell interprets {{ }} braces
cat file_with_jinja.yml
grep "pattern" file_with_jinja.yml
echo "{{ app_name }}"

# GOOD - use read_file / grep_search tools instead (they bypass the shell)

# GOOD - if terminal is required, use Python
python3 -c "print(open('file.yml').read()[:500])"
```

### Rule: Never Use Unquoted Heredocs with Dynamic Content

```bash
# BAD - heredoc interprets variables and braces, causes heredoc> hang
cat > file.yml << EOF
name: "{{ app_name }}"
EOF

# GOOD - single-quote the delimiter to prevent interpretation
cat > file.yml << 'EOF'
name: "{{ app_name }}"
EOF

# BEST - use Python or the insert_edit_into_file tool
```

### Rule: Prefer Non-Terminal Tools

| Task | Use This | Not This |
|------|----------|----------|
| Read a file | `read_file` tool | `cat` / `head` / `tail` in terminal |
| Search in file | `grep_search` tool | `grep` in terminal |
| Write / edit a file | `insert_edit_into_file` or `replace_string_in_file` tool | `cat > file << EOF` in terminal |
| Verify edits applied | `read_file` tool | `cat file` in terminal |

**When you must use the terminal** (running commands, playbooks, aws cli):
- Pipe through `| cat` to avoid pagers
- Use `2>&1` to capture stderr
- Run long commands with `isBackground: true`

### Rule: If Terminal Hangs (dquote>, heredoc>, quote>)

If the terminal produces no output or you suspect it is stuck:

1. **Do NOT keep waiting** - the session will not recover on its own
2. **Run a new terminal command** - the tool starts a fresh session
3. **Switch to a non-terminal tool** (read_file, grep_search, insert_edit_into_file)
4. **Re-validate** using the appropriate tool after recovering

---

## Git Commit Workflow - CRITICAL

### Problem Solved
The project experienced recurring `dquote>` console errors when making git commits. This has been analyzed and resolved.


### Rule 1: Keep Git Commit Messages Simple (Primary Method)

**ALWAYS use simple commit messages without internal quotes:**

```bash
# GOOD - Simple messages work perfectly
git commit -m "docs: add deployment guide"
git commit -m "fix: correct CloudWatch permissions"
git commit -m "feat: add validation script"
git commit -m "docs: update MAINTENANCE_CHECKLIST for quarterly reviews"

# BAD - These cause dquote> errors
git commit -m "docs: add 'comprehensive' guide"
git commit -m "fix: update 'CloudWatch' 'permissions'"
git commit -m "docs: update 'guide' with 'new' features"
```

**Why?**
- No quote escaping needed
- Shell interprets message correctly
- Console shows clean output
- Commits go through immediately

### Rule 2: For Complex Messages, Use File Method (Backup Method)

**If you need multi-line or complex messages, use commit message file:**

```bash
# Create message file with complex content
cat > /tmp/commit_msg.txt << 'EOF'
docs: comprehensive documentation update

Added new guides:
- UPDATING_APPLICATION.md: Deploy code changes
- SECURITY_HARDENING.md: Secure your server
- WAF_CONFIGURATION.md: Web Application Firewall
- CLOUDFRONT_CDN.md: Global CDN

All links verified with 100% accuracy.
EOF

# Commit using file (avoids ALL quote issues)
git commit -F /tmp/commit_msg.txt

# Clean up
rm /tmp/commit_msg.txt
```

**Why this method?**
- No shell interpretation of file contents
- No quotes to escape
- Multi-line messages work perfectly
- Special characters handled correctly
- Always works, never fails

### Rule 3: NEVER Nest Quotes in -m Parameter

```bash
# NEVER DO THIS
git commit -m "docs: update 'guide' to 'version 2'"
git commit -m "docs: add 'comprehensive' setup with 'best' practices"
git commit -m "fix: handle 'special' 'characters' correctly"

# DO THIS INSTEAD
git commit -m "docs: update guide to version 2"
git commit -m "docs: add comprehensive setup with best practices"
git commit -m "fix: handle special characters correctly"

# OR use file method if you really need quotes
```

### Rule 4: If dquote> or heredoc> Appears

If you see `dquote>`, `heredoc>`, or `quote>` in console output:

1. **Stop immediately** - do not send more text
2. **Run a new terminal command** - the tool starts a fresh session
3. **Use the file method** for the failed operation
4. **See also:** [Shell Command Safety](#shell-command-safety---critical) for prevention rules

```bash
# Recovery: Use file method for git
cat > /tmp/msg.txt << 'EOF'
Your message here without worrying about quotes
EOF
git commit -F /tmp/msg.txt && rm /tmp/msg.txt
```

---

## Workflow Checklist

Before committing, verify:

- [ ] Using simple message format (no internal quotes)
  - OR using file method for complex messages
- [ ] Message is descriptive (tells what changed, not how)
- [ ] No 'quotes' inside the -m "message" parameter
- [ ] Related files staged with git add
- [ ] Running from project root directory

---

## Example Good Commits

```bash
# Fix
git commit -m "fix: correct CloudWatch IAM policy name"

# Docs
git commit -m "docs: add comprehensive deployment guide"

# Feature
git commit -m "feat: add automated validation script"

# Refactor
git commit -m "refactor: simplify git commit handling"

# Multiple changes (keep simple)
git commit -m "docs: add guides and maintenance system"
```

---

## Example Bad Commits (Will Cause dquote>)

```bash
# Don't use these
git commit -m "docs: add 'guide' with 'features'"
git commit -m "fix: correct 'CloudWatch' 'permissions'"
git commit -m "feat: implement 'validation' and 'testing'"

# These will show dquote> error and fail
```

---

## Git Command Best Practices

### For All Git Operations:

1. **Use simple, descriptive messages**
   - First line: One-line summary (50 chars max)
   - Then blank line
   - Then details if needed

2. **Prefer file method for complex messages**
   ```bash
   cat > /tmp/msg.txt << 'EOF'
   Summary line here

   Details:
   - Item 1
   - Item 2
   EOF
   git commit -F /tmp/msg.txt && rm /tmp/msg.txt
   ```

3. **Always verify before committing**
   ```bash
   git status  # See what's staged
   git diff --staged  # See exact changes
   ```

4. **Push immediately after committing**
   ```bash
   git push origin main
   ```

---

## Reference Documents

- **deployment/scripts/git-commit-safe.sh** - Helper script for safe git commits

---

## UI Design System - CRITICAL

### Problem
Every template (`base.html`, `landing.html`, `comics_list.html`, `account.html`, etc.)
re-declares its own `.btn`, `.btn-primary`, `.modal`, `.modal-content`, `.action-section`,
and color values — often with slight inconsistencies. This creates visual drift and makes
palette changes require editing every file.

### Rule: Use CSS Custom Properties from `app/static/css/tokens.css`

All colors, spacing, radii, and shadows are defined once in `app/static/css/tokens.css`.
Templates and inline styles must reference these variables — never hard-code hex values.

```css
/* app/static/css/tokens.css — single source of truth */
:root {
  /* Backgrounds */
  --color-bg:             #111210;   /* body background (warm near-black) */
  --color-surface:        #1B1B1B;   /* cards, header, footer */
  --color-elevated:       #242422;   /* modals, dropdowns, popovers */
  --color-inset:          #161615;   /* input fields, code blocks */

  /* Borders */
  --color-border:         #2E2E2A;
  --color-border-hover:   #3A3A36;
  --color-border-focus:   #595F39;   /* same as accent */

  /* Text */
  --color-text:           #E4E4DE;   /* Ethereal Ivory — primary */
  --color-text-muted:     #C4C5BA;   /* Sophisticated Sage — secondary */
  --color-text-dim:       #7A7B72;   /* placeholders, disabled, captions */

  /* Accent */
  --color-accent:         #595F39;   /* Muted Moss — buttons, active nav, links */
  --color-accent-hover:   #6B7244;
  --color-accent-subtle:  rgba(89, 95, 57, 0.12); /* accent tint for backgrounds */
  --color-accent-text:    #E4E4DE;   /* text ON accent-colored backgrounds */

  /* Semantic */
  --color-danger:         #C45C5C;
  --color-danger-subtle:  rgba(196, 92, 92, 0.12);
  --color-success:        #5C8A5C;
  --color-success-subtle: rgba(92, 138, 92, 0.12);
  --color-info:           #5C9EB8;
  --color-info-subtle:    rgba(92, 158, 184, 0.12);
  --color-warning:        #B8A05C;
  --color-warning-subtle: rgba(184, 160, 92, 0.12);

  /* Typography */
  --font-family:          'Outfit', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-size-xs:         11px;
  --font-size-sm:         13px;
  --font-size-base:       14px;
  --font-size-md:         16px;
  --font-size-lg:         20px;
  --font-size-xl:         28px;
  --font-size-2xl:        48px;

  /* Spacing */
  --space-xs:  4px;
  --space-sm:  8px;
  --space-md:  16px;
  --space-lg:  24px;
  --space-xl:  48px;

  /* Radii */
  --radius-sm:  6px;    /* buttons, inputs, tags */
  --radius-md:  10px;   /* cards, small containers */
  --radius-lg:  14px;   /* modals, sections, large containers */

  /* Shadows (neutral — no colored glows) */
  --shadow-sm:  0 1px 2px rgba(0, 0, 0, 0.3);
  --shadow-md:  0 4px 12px rgba(0, 0, 0, 0.4);
  --shadow-lg:  0 8px 24px rgba(0, 0, 0, 0.5);
}
```

### Rule: Use Shared Component Classes from `app/static/css/components.css`

Common UI components are defined once in `app/static/css/components.css`. Templates must
use these classes — never re-declare `.btn`, `.btn-primary`, `.modal`, etc. in `<style>` blocks.

**Shared components** (defined in `components.css`, used everywhere):

| Component | Class(es) | Notes |
|-----------|-----------|-------|
| Buttons | `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-danger`, `.btn-sm` | Consistent padding, radius, hover |
| Modals | `.modal`, `.modal-content`, `.modal-header`, `.modal-body`, `.close-btn` | Escape-to-close in `base.html` JS |
| Cards | `.card`, `.stat-card` | Surface background, border, radius |
| Forms | `.form-group`, `.form-label`, `.form-input`, `.form-select` | Focus ring uses `--color-border-focus` |
| Section labels | `.section-label` | Uppercase, letter-spaced, with optional icon |
| Page header | `.page-header`, `.page-header h1`, `.page-header p` | Consistent across all pages |
| Action section | `.action-section` | Grouped actions with border and hover |
| Notifications | `.notification`, `.notification.success/error/info` | Positioned top-center |
| Footer bar | `.footer-bar` | Fixed bottom bar with actions |

**Page-specific styles** remain in each template's `{% block extra_css %}` block, but only
for layout and features unique to that page (grid columns, table tweaks, page-specific modals).

### Rule: Never Hard-Code Colors

```css
/* BAD — color will drift across templates */
.my-element { color: #FFE500; background: #1A1A1A; }

/* GOOD — uses design tokens */
.my-element { color: var(--color-accent); background: var(--color-surface); }
```

### Rule: Never Use Inline Style for Hover/Focus Effects

```html
<!-- BAD — cannot be overridden, causes sticky hover on mobile -->
<button onmouseover="this.style.background='#F5DB00'" onmouseout="this.style.background='#FFE500'">

<!-- GOOD — use a CSS class -->
<button class="btn btn-primary">
```

### Rule: No Colored Glow Shadows

```css
/* BAD — dated 2018 glow effect */
box-shadow: 0 4px 16px rgba(255, 229, 0, 0.3);

/* GOOD — neutral shadow */
box-shadow: var(--shadow-md);
```

### Rule: Consistent Border Radius

| Element | Radius |
|---------|--------|
| Buttons, inputs, tags | `var(--radius-sm)` (6px) |
| Cards, comic cards, small containers | `var(--radius-md)` (10px) |
| Modals, sections, large containers | `var(--radius-lg)` (14px) |

### Color Palette Reference

| Name | Hex | Role |
|------|-----|------|
| Ethereal Ivory | `#E4E4DE` | Primary text |
| Sophisticated Sage | `#C4C5BA` | Secondary/muted text |
| Eerie Black | `#1B1B1B` | Card/surface backgrounds |
| Muted Moss | `#595F39` | Primary accent (buttons, active states, links) |
| Background | `#111210` | Body background (warm near-black) |
| Elevated | `#242422` | Modal/dropdown backgrounds |
| Danger | `#C45C5C` | Destructive actions |
| Info | `#5C9EB8` | Informational highlights |
| Success | `#5C8A5C` | Positive confirmations |

### Template Checklist

Before editing any template:

- [ ] `tokens.css` and `components.css` are linked in `base.html` `<head>`
- [ ] No new `.btn` / `.btn-primary` / `.modal` declarations in `{% block extra_css %}`
- [ ] All colors reference `var(--color-*)` tokens
- [ ] No `onmouseover` / `onmouseout` inline event handlers for styling
- [ ] No `rgba(255, 229, 0, ...)` colored glow shadows
- [ ] Border-radius uses `var(--radius-sm/md/lg)`
- [ ] Page-specific styles only contain layout unique to that page

---

## Documentation Standards

All documentation in `deployment/docs/` follows a consistent style modeled after
professional vendor guides (Cisco, HashiCorp, AWS). Apply these rules when creating
or editing any `.md` file in the project.

### File Structure

**Guides** (procedural, step-by-step):

```markdown
# Chapter N: Title

One-line description of what this chapter covers.

---

## Section Name

Content...

---

## Next step

Continue to [Chapter N+1: Title](NEXT_FILE.md).

## See also

- [Chapter X: Title](FILE.md) — brief reason
- [Reference: Title](../reference/FILE.md) — brief reason
```

**Reference docs** (descriptive, not procedural):

```markdown
# Title Reference

One-line description.

---

## Section Name

Content...
```

### Rules

| Rule | Do | Do Not |
|------|----|--------|
| Title format (guides) | `# Chapter 6: Monitoring` | `# CloudWatch Monitoring Guide` |
| Title format (reference) | `# Architecture Reference` | `# Architecture Reference Guide v5.0` |
| Subtitle | One plain sentence | Bold text, version numbers, dates, status badges |
| Ending (guides) | Single `## Next step` link, optional `## See also` (2–3 links max) | Multiple "next step" sections, decision tables, "pick one" blocks |
| Prerequisite reference | `> Prerequisite: Complete [Chapter 1](PREREQUISITES.md).` | 15-line checklist re-verifying the previous chapter |
| Cross-references | `See [Chapter 5: Operations](OPERATIONS.md).` | `→ **[OPERATIONS.md](OPERATIONS.md)** — Full guide!` |
| Tone | Direct, declarative prose | Emojis in headings, exclamation marks, "Think of it as…" analogies |
| Metadata | None — use Git history | `**Version:** 5.0`, `**Date:** Feb 2026`, `**Status:** Production-Ready` |
| Variable placeholders | Use `{app_name}` inline without explanation | Multi-line note explaining what `{app_name}` means (stated once in Ch. 1) |
| Emoji | Allowed in verification output (`✓`) and warnings (`⚠️`) | Not in headings, not in bullet lists as decoration (`🚀`, `📋`, `🎉`) |

### Chapter Numbers

Guides are numbered 1–13 and live in `deployment/docs/guides/`. Reference docs live in
`deployment/docs/reference/`. The table of contents is `deployment/docs/README.md`.
When adding a new guide, assign the next number and update the README.

| Chapter | File |
|---------|------|
| 1 | guides/PREREQUISITES.md |
| 2 | guides/QUICKSTART.md |
| 3 | guides/MANUAL_DEPLOYMENT.md |
| 3b | guides/AWS_CONSOLE_DEPLOYMENT.md |
| 4 | guides/UPDATING_APPLICATION.md |
| 5 | guides/OPERATIONS.md |
| 6 | guides/MONITORING.md |
| 7 | guides/SECRET_MANAGEMENT.md |
| 8 | guides/SECURITY_HARDENING.md |
| 9 | guides/MULTI_USER.md |
| 10 | guides/CLOUDFRONT_CDN.md |
| 11 | guides/WAF_CONFIGURATION.md |
| 12 | guides/GIT_CONFIGURATION.md |
| 13 | guides/DECOMMISSION.md |

### Writing Checklist

Before finalizing any documentation change:

- [ ] Title matches the `# Chapter N: Title` pattern (guides) or `# Title` (reference)
- [ ] No version, date, or status metadata in the header
- [ ] No repeated prerequisite checks from the previous chapter
- [ ] File ends with a single `## Next step` (guides) or nothing (reference)
- [ ] No emojis in section headings
- [ ] Cross-references use chapter numbers: "See Chapter 5" not "See OPERATIONS.md"
- [ ] `docs/README.md` table of contents is updated if a file was added or renamed

---

## Summary

| Aspect | Guideline |
|--------|-----------|
| Primary Method | Simple commit messages (no internal quotes) |
| Backup Method | File method for complex messages |
| Never Do | Nest quotes in -m parameter |
| If dquote> Appears | Use file method instead |
| Pattern | git commit -m "type: description" |
| Example | git commit -m "docs: add deployment guide" |

---

**Key Point:** Following Rule 1 (simple messages) and Rule 2 (file method for complex) will PREVENT all dquote> errors from happening again.

---

**Last Updated:** March 24, 2026

