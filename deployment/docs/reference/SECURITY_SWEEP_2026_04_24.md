# Security Sweep — April 24, 2026

Sweep run against the rules in
[AGENTS.md → Secure Coding Standards](../../AGENTS.md#secure-coding-standards---critical).
Findings are categorized as **violation** (must fix) or **acceptable**
(intentional public endpoint or already hardened).

## Summary

| Check | Result |
|-------|--------|
| Raw `request.files[...].filename` reaching paths/S3 keys without `secure_filename` | **Acceptable** — only used for validation messages; storage path goes through `generate_unique_filename` (which calls `secure_filename`). |
| Image uploads missing `Image.verify()` | **1 violation** — extension/size are checked at the route, but Pillow validation only happens later in `comic_service._process_uploads`, after the file has already been saved to disk. |
| `requests.*` calls missing `timeout=` | **0 violations** — all 11 calls in `app/services/ebay_service.py` set `timeout=10` or `timeout=15`. |
| State-changing routes missing `@login_required` / `@csrf_required` | **3 routes without decorators** — 2 are intentional public endpoints (login, eBay deletion webhook), 1 is the public analytics tracker which is hardened with rate-limit + size cap. |

## Findings

### 1. Image upload — Pillow validation runs after the bytes hit disk (medium)

**Files:**

- `app/routes/api/comics.py` lines 215–241 (`add_comic`, POST `/api/comic`)
- `app/routes/api/comics.py` lines 387–409 (`update_comic`, PUT `/api/comic/<sku>`)
- `app/services/comic_service.py` lines 914–936 (`_process_uploads`)

**Issue:** The route layer only checks the extension (`allowed_file`) and a 10 MB
size cap. Pillow's `Image.open(...).verify()` is then run inside
`comic_service._process_uploads`, but **after** `image_file.save(file_path)` has
written the bytes to the temporary upload folder. A crafted file with a valid
extension but no real image content (or a polyglot file) is briefly persisted
to disk before being detected and removed.

**Fix:** Call `validate_uploaded_image()` from the new
`app/utils/upload_security.py` at the route entry point, before any `save()`.
This consolidates the extension allow-list, size cap, and `Image.verify()` in
one place that runs against the in-memory stream.

```python
# app/routes/api/comics.py
from app.utils.upload_security import validate_uploaded_image, UploadValidationError

for file in files:
    if file and file.filename:
        try:
            validate_uploaded_image(file)
        except UploadValidationError as exc:
            return jsonify({'success': False, 'message': str(exc)}), exc.status_code
```

The `Image.verify()` block in `comic_service._process_uploads` can stay as a
defence-in-depth check (it now runs on a file the route has already accepted).

### 2. Public route — `POST /api/ebay/marketplace-account-deletion` (acceptable)

- `app/routes/api/ebay.py` line 890.
- Required by eBay's marketplace-deletion webhook contract; cannot carry
  `@login_required` (eBay calls it).
- The handler implements eBay's challenge/response signed by a verification
  token, which is the correct authentication for this endpoint.

**Action:** none. Document the exception inline in the docstring (already done).

### 3. Public route — `POST /api/analytics/track` (acceptable, already hardened)

- `app/routes/api/analytics.py` line 22.
- Intentionally un-authed so anonymous landing-page traffic can be tracked.
- Hardened in-line with: 16 KB payload cap, 20-event batch ceiling, 60 req/min
  per-IP rate limit, `force=True, silent=True` on JSON parsing, fallback to a
  bounded raw-data parse.

**Action:** none. The hardening is explicitly called out in the existing
docstring. If the rules were ever relaxed, this would become a violation.

### 4. Public route — `POST /auth/login` (acceptable)

- `app/routes/auth.py` line 205.
- This is the login endpoint itself — `@login_required` cannot apply, and CSRF
  protection on login forms is delivered through the form-level CSRF token
  (`generate_csrf_token`) embedded in `templates/login.html`, validated inside
  the handler.

**Action:** none. Confirmed during sweep.

### 5. `requests.*` timeouts — clean

All 11 outbound HTTP calls in `app/services/ebay_service.py` set
`timeout=10` or `timeout=15`. No bare `requests.get(url)` / `requests.post(url)`
calls remain.

### 6. `request.files[...].filename` use — clean (defence-in-depth still recommended)

The only places that touch `file.filename` are:

- `app/routes/api/comics.py` — used for *display only* in error messages
  (`f'Invalid file type: {file.filename}'`). The filename is not concatenated
  into a path or key.
- `app/services/comic_service.py` line 916 — passed to
  `allowed_file(image_file.filename, …)` and `generate_unique_filename(image_file.filename)`,
  the latter of which calls `secure_filename` internally.

**Action:** none required. With the new `validate_uploaded_image()` helper, the
display strings will use the `secure_filename`-d name instead of the raw value
once routes are migrated.

## Migration checklist (when adopting `upload_security.validate_uploaded_image`)

- [x] `app/routes/api/comics.py::add_comic` — replace lines 215–241 with a
      `validate_uploaded_image(file)` call.
- [x] `app/routes/api/comics.py::update_comic` — replace lines 387–409 with a
      `validate_uploaded_image(file)` call.
- [x] Keep the `Image.verify()` block in `comic_service._process_uploads` as
      defence-in-depth.
- [x] No callers of `request.files[...].filename` use it for paths today, so
      no further changes are needed there.

## Out-of-scope (noted for later)

These items are not violations of the current rules but are worth a future
review:

- `app/services/comic_service.py::_process_uploads` calls `image_file.save()`
  before its own Pillow check. After the route-level migration above, this
  becomes belt-and-braces; before, it is the *only* content check.
- Pillow's `Image.MAX_IMAGE_PIXELS` is left at the default. If we ever take
  uploads from untrusted sources at scale, set it to e.g. `40_000_000` in the
  app factory to make decompression-bomb rejection deterministic.
- `app/utils/whatnot_validators.py::allowed_file` is a duplicate of the logic
  inside `validate_uploaded_image`. Keep for now (used by other call sites);
  collapse when the upload paths are unified.

