# Copilot Instructions

**These instructions are automatically loaded for every Copilot session in this project.**

For full details see [AGENTS.md](../AGENTS.md) in the project root.

---

## Session Memory - READ FIRST EVERY SESSION

AI agents have **no memory between conversations**. To bridge that, this repo
keeps a local session-notes file the agent reads at the start of every session
and appends to on request.

**File:** `.copilot/SESSION_NOTES.md` (gitignored, local working memory only)

### At the start of every session

1. Use the `read_file` tool to read `.copilot/SESSION_NOTES.md` if it exists.
2. If it has session entries, briefly summarize the most recent 1–2 entries to
   the user before starting new work, so they can confirm the context is right.
3. If it does not exist or is empty, proceed normally.

### Trigger phrases the user can say

Short forms are the primary triggers. Longer natural-language forms still work.

| User says | Agent does |
|-----------|------------|
| `ck` / `checkpoint` / `save context` / `remember this` | Append a new dated entry to the **Sessions** section using the template in the file. |
| `ctx` / `show context` / `recall` / `what were we doing` | Read the file and summarize recent entries. |
| `wipe` / `clear memory` / `start fresh` / `forget everything` | Truncate the file's **Sessions** section (keep the header), confirm what was cleared. |
| `arc` / `archive memory` | Move all session entries to `.copilot/SESSION_NOTES.archive.md`, then clear. |

A short trigger (`ck`, `ctx`, `wipe`, `arc`) is a command only when it is the
entire user message. Inside a longer sentence, treat it as normal text.

### Proactively offer to checkpoint when

- A non-trivial decision was just made (architecture, library choice, abandoned approach).
- The user is about to switch tasks or branches.
- A long debugging session just resolved.

The full convention, entry template, and rules live in `.copilot/SESSION_NOTES.md` itself.

---

## Shell Command Safety - CRITICAL

### Never Output Jinja2 Braces Through the Terminal

The zsh shell interprets `{{ }}` as glob patterns. Commands that output Jinja2 content will hang or produce empty output.

```bash
# BAD - causes empty output or hangs
cat file_with_jinja.yml
grep "pattern" file_with_jinja.yml
head file_with_jinja.yml

# GOOD - use the read_file / grep_search tools instead (they bypass the shell)
# GOOD - if terminal is required, use Python:
python3 -c "print(open('file.yml').read()[:500])"
```

### Never Use Unquoted Heredocs with Dynamic Content

```bash
# BAD - shell interprets {{ }} and $vars, causes heredoc> hang
cat > file.yml << EOF
name: "{{ app_name }}"
EOF

# GOOD - single-quote the delimiter
cat > file.yml << 'EOF'
name: "{{ app_name }}"
EOF

# BEST - use Python or the insert_edit_into_file tool to write files
```

### Prefer Non-Terminal Tools

| Task | Use This | Not This |
|------|----------|----------|
| Read a file | `read_file` tool | `cat` / `head` / `tail` in terminal |
| Search in file | `grep_search` tool | `grep` in terminal |
| Write / edit a file | `insert_edit_into_file` or `replace_string_in_file` tool | `cat > file << EOF` in terminal |
| Verify edits applied | `read_file` tool | `cat file` in terminal |

### If Terminal Hangs (no output, or dquote> / heredoc> / quote>)

1. **Do NOT keep waiting** - it will not recover
2. **Run a new terminal command** - the tool starts a fresh session
3. **Switch to a non-terminal tool** to accomplish the task
4. **Re-validate** using `read_file` after recovering

### Ansible Playbooks

- Run with `isBackground: true` and retrieve output with `get_terminal_output` for long-running playbooks
- Pipe short playbook runs through `2>&1` to capture all output

---

- Error: The eBay service for looking up sold prices is currently unavailable due to daily API limits. However, you can still use the image search results (which show current prices) as a guide.
## Git Branching Rules

**Default: do not create feature branches.** Commit directly to whatever branch
the user is currently on (typically `main`). The user controls branching
strategy — only create a branch when the user explicitly asks for one
(e.g. *"branch this"*, *"new feature branch for X"*, *"work on this in a branch"*).

If you genuinely believe a branch is warranted (large refactor, risky
multi-step change, parallel exploration), **ask before creating it** — do not
create one preemptively.

---

## Git Commit Rules

```bash
# ALWAYS - simple messages, no internal quotes
git commit -m "docs: add deployment guide"
git commit -m "fix: correct IAM role permissions"

# NEVER - nested quotes cause dquote> hangs
git commit -m "docs: add 'comprehensive' guide"

# FOR COMPLEX MESSAGES - use file method
cat > /tmp/msg.txt << 'EOF'
feat: multi-line commit message

- Detail one
- Detail two
EOF
git commit -F /tmp/msg.txt && rm /tmp/msg.txt
```

---

## Documentation Standards

All docs in `deployment/docs/` follow a consistent vendor-guide style. See [AGENTS.md](../AGENTS.md) for the full rules.

**Key rules:**

- Guides use `# Chapter N: Title` with a one-line subtitle — no version/date metadata
- One prerequisite note per file, not a re-verification checklist
- End guides with a single `## Next step` link — no repeated "next step" sections
- No emojis in headings, no analogies, no marketing bullets
- Cross-reference by chapter number: "See [Chapter 5: Operations](OPERATIONS.md)"
- Chapter numbers (1–13) are tracked in `deployment/docs/README.md`

---

## UI Design System - CRITICAL

All colors, spacing, and component classes live in two shared CSS files. See [AGENTS.md](../AGENTS.md) for full details.

**Key rules:**

- All colors use `var(--color-*)` tokens from `app/static/css/tokens.css` — never hard-code hex
- Shared components (`.btn`, `.btn-primary`, `.modal`, `.modal-content`, `.form-input`, etc.) come from `app/static/css/components.css` — never re-declare in template `<style>` blocks
- No `onmouseover` / `onmouseout` inline handlers for hover effects — use CSS classes
- No colored glow shadows (`rgba(255, 229, 0, ...)`) — use `var(--shadow-sm/md/lg)`
- Border-radius: `var(--radius-sm)` 6px buttons/inputs, `var(--radius-md)` 10px cards, `var(--radius-lg)` 14px modals
- Page-specific styles in `{% block extra_css %}` only for layout unique to that page

**Color palette:**

| Token | Hex | Role |
|-------|-----|------|
| `--color-bg` | `#1B1A1B` | App background |
| `--color-surface` | `#242223` | Top/bottom bars, core surfaces |
| `--color-elevated` | `#2D2B2C` | Cards, modals |
| `--color-inset` | `#171616` | Input fields, code blocks |
| `--color-text` | `#E8E8E6` | Primary text |
| `--color-text-muted` | `#C5C2BE` | Secondary text |
| `--color-accent` | `#E2E800` | Primary highlight accent (bright yellow) |
| `--color-accent-2` | `#5C9EB8` | Secondary accent (steel blue) |
| `--color-danger` | `#C45C5C` | Destructive actions |
| `--color-ebay` | `#00BFFF` | eBay brand blue |
| `--color-whatnot` | `#FF00FF` | WhatNot brand magenta |

---

## General Coding Standards

Lessons from the April 2026 hardening pass. See [AGENTS.md](../AGENTS.md#general-coding-standards) for full details and examples.

### Python rules

- **Never `str(e)` in JSON responses** — use `safe_error_message(e)` from `app/utils/logging_utils.py`. Full detail goes to the logger only.
- **All imports at module level** — never inside functions, route handlers, or `except` blocks. Imports in handlers cause unresolved-reference warnings and hide circular deps. **Two allowed exceptions, both requiring a comment:** (1) `# Deferred: avoids circular import` and (2) `# Deferred: requires Flask app context` (service singletons constructed before app starts).
- **Initialize before `try`** — any variable referenced in `except`/`finally` must be assigned before the `try` block, not inside it.
- **Use Pythonic style and docs** — follow PEP 8 and PEP 257 (`snake_case` names, clear docstrings for public modules/classes/functions, line lengths compatible with `black`).
- **Prefer named callables over inline `lambda`** — use `def` for any non-trivial logic so stack traces, typing, and reuse stay clear. Tiny sort keys are acceptable.
- **Use type hints where applicable** — annotate public functions/methods and complex return types; keep type aliases near the top of the module.
- **Format with `black` and sort imports with `isort`** — keep import order stable and avoid style churn in reviews.
- **Meaningful naming, readability, DRY** — use descriptive names, extract repeated logic into helpers, and keep functions small/single-purpose.
- **Catch specific exceptions first** — avoid broad `except Exception` unless you log and re-raise or sanitize at a boundary.
- **No side effects at import time** — module import should define symbols only; defer network/file/session-dependent work to runtime paths.

### JavaScript rules

- **Confirm = snapshot → try → finally** — the confirm function owns the full lifecycle. Snapshot state into locals, execute in `try`, reset `pending*` state in `finally`. Cancel resets immediately with no try/finally.
- **Executors take arguments** — executor functions receive values as parameters; they never read or reset global `pending*` / `bulk*` state.
- **Declare state together** — all variables in a logical state group go in one contiguous block. No re-declarations in nested scopes.
- **Registry for grouped DOM ops** — define a constant array of IDs and one shared helper instead of duplicating `hide`/`pop` calls across branches.

### Checklist additions

- [ ] No `str(e)` in jsonify responses — use `safe_error_message(e)`
- [ ] All imports at module top — not inside handlers or except blocks
- [ ] Variables used in except/finally initialized before the try
- [ ] PEP 8 + PEP 257 followed for modified Python modules
- [ ] Public functions/methods have type hints where practical
- [ ] Non-trivial lambdas replaced with named functions
- [ ] Files are formatted with `black`; imports are sorted with `isort`
- [ ] Naming is descriptive; duplicated logic extracted into shared helpers
- [ ] JS confirm: snapshot → try → finally cleanup; executors take args, never reset state
- [ ] Related JS state vars declared in one block; registry used for grouped modal teardown

---

## Secure Coding Standards - CRITICAL

**Read the full rules in [AGENTS.md → Secure Coding Standards](../AGENTS.md#secure-coding-standards---critical) before writing any code that touches user input, files, secrets, or external data.**

These rules are mandatory for every change. If a code path violates one of them, fix the
code path — do not add an exception.

### File uploads (images, CSVs, anything from the client)

- **Always** wrap the client-supplied filename with `werkzeug.utils.secure_filename()` before joining it to a path. Never pass `request.files['x'].filename` straight into `os.path.join` / `open` / S3 keys.
- **Always** validate image content with `PIL.Image.open(stream).verify()` (or re-decode) at the upload site — do not trust the extension or `Content-Type` alone. Reject on `UnidentifiedImageError` / `Image.DecompressionBombError`.
- **Always** enforce a server-side size cap (`MAX_CONTENT_LENGTH` and/or explicit `len(stream.read())` check) and an allow-list of extensions/MIME types. Reject everything else.
- **Never** serve uploaded files from a directory that also executes code (no uploads under `app/`, `static/` only for processed/sanitized output, prefer S3).
- **Never** use the original filename in the stored key — generate one (UUID, SKU-based) so two users cannot collide and a crafted name cannot escape the directory.

### Path handling

- **Never** build filesystem paths by string concatenation with user input. Use `pathlib.Path` or `os.path.join` plus `secure_filename`, then assert the resolved path is inside the expected base (`Path(base).resolve() in resolved.parents`).
- **Never** trust `..`, absolute paths, null bytes, or symlinks from user input. Reject before using the value.
- Multi-user file access **must** go through helpers in `app/utils/user_context.py`. Do not hand-craft `instance/data/{username}/...` paths in routes or services.

### Subprocess / shell / SQL / templates

- **Never** pass user input to `subprocess.*` with `shell=True`. Use a list of args and `shell=False`.
- **Never** build SQL/CSV/HTML/JSON by f-string concatenation of user input. Use parameterized APIs (`csv.writer`, `json.dumps`, Jinja autoescape, parameterized queries).
- **Never** disable Jinja autoescape or use `{{ value|safe }}` on user-controlled data.
- **Never** use `eval`, `exec`, `pickle.loads`, `yaml.load` (use `yaml.safe_load`), or `subprocess` with unvalidated input.

### Authentication & authorization

- Every route that reads or mutates user data **must** carry `@login_required` (and `@csrf_required` for state-changing requests). State-changing = POST/PUT/PATCH/DELETE.
- **Always** scope file/CSV/S3 access to the current `session['username']` via `user_context` helpers. Never accept a username from the request body or query string for authorization decisions.
- **Never** log secrets, full session cookies, raw passwords, eBay tokens, or AWS credentials. Use `safe_error_message()` from `app/utils/logging_utils.py` for client-facing error strings in production.

### Secrets & config

- **Never** hard-code API keys, tokens, passwords, or AWS credentials. Read them via `get_secret()` in `app/config.py` (Secrets Manager → env → default).
- **Never** commit `.env`, decrypted vault, or `~/.vault_pass`. Vault stays encrypted in `deployment/group_vars/vault.yml`.
- Per-user eBay credentials live in AWS Secrets Manager via `user_secrets_service.py` — do not write them to CSV, JSON, or logs.

### External requests & SSRF

- **Always** set an explicit `timeout=` on every `requests.*` / `urllib` call. No unbounded waits.
- **Never** fetch a URL supplied by the client without an allow-list of hosts/schemes (block `file://`, `http://169.254.169.254`, private CIDRs).

### Input validation & rate limiting

- Validate every API input shape at the entry point. Reject unknown fields, enforce types, and cap string lengths before passing to services.
- Respect `app/security.py` rate limiting — do not add new public endpoints that bypass it. Sensitive endpoints (login, password reset, bulk eBay actions) need explicit rate limits.

### Pre-commit security checklist

Before finishing any change, verify:

- [ ] No `request.files[...].filename` reaches a path/S3 key without `secure_filename`
- [ ] All image uploads run through `Image.open(...).verify()` and a size cap
- [ ] No new `shell=True`, `eval`, `pickle`, `yaml.load`, or `|safe` on user data
- [ ] Every new state-changing route has `@login_required` + `@csrf_required`
- [ ] No secrets, tokens, or full request bodies in log messages
- [ ] All outbound `requests` calls have an explicit `timeout`
- [ ] User-controlled paths are resolved and confined under the expected base
- [ ] CSV writes go through `csv_service` (which handles locking + sanitization), not raw `open(..., 'w')`

---

## eBay Integration — Key Patterns

- **XML sanitization:** `EbayService._sanitize_trading_payload_strings()` auto-escapes bare `&` in all `AddFixedPriceItem` / `ReviseFixedPriceItem` payloads. Do not manually escape titles.
- **Scheduled ↔ Live toggle:** Call `POST /api/comic/<sku>/ebay/relist` with `{ "mode": "list" }` to go live or `{ "mode": "future", "schedule_time": "<ISO>" }` to schedule. The endpoint ends the existing listing internally — no separate end call needed.
- **Bulk actions:** Three-modal flow — action picker → item selector → confirm. `bulkCurrentAction` values: `add`, `update`, `remove`, `unlink`, `go-live`, `go-scheduled`.

---

## Project Context

- **Stack:** Python / Flask application with Ansible deployment to AWS EC2
- **Shell:** zsh on macOS
- **Deployment config:** `deployment/` directory with Ansible playbooks, group_vars, vault
- **Ansible variables:** All configuration in encrypted `deployment/group_vars/vault.yml`
- **Vault secrets:** Access with `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass`
- **S3 bucket name:** Comes from `s3_bucket_name` in vault (not derived from `app_name`)
