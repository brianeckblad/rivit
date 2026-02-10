# Summary of App Name Genericization Changes

**Date:** February 10, 2026  
**Purpose:** Remove hardcoded "app_item_listing_tool" references and make the application name fully configurable

## Key Changes Made

### 1. Configuration (Already Done)
- ✅ **deployment/group_vars/all.yml** - Updated to use `app_name: rampe` as the default
- ✅ **deployment/group_vars/all.yml** - Added `venv_dir: "/home/{{ app_user }}/.venv"` (venv in home directory)

### 2. Service Files & Templates

#### Renamed Files:
- ✅ **deployment/files/app_item_listing_tool.service** → **deployment/files/app.service.j2**
  - Now uses Jinja2 variables: `{{ app_name }}`, `{{ venv_dir }}`, `{{ service_name }}`, `{{ log_dir }}`
  - Adds `APP_SERVICE_NAME={{ service_name }}` to environment

#### Updated Templates:
- ✅ **deployment/templates/env.j2**
  - Added `APP_SERVICE_NAME={{ service_name }}`
  - Added `CLOUDWATCH_NAMESPACE={{ app_display_name }}`
  - All paths now use `{{ app_dir }}` variable

- ✅ **deployment/templates/supervisor.conf.j2**
  - Already using variables (no changes needed)

### 3. Python Code

#### app/__init__.py
- ✅ Updated `_setup_service_logger()` to use `os.environ.get('APP_SERVICE_NAME', 'rampe')` for log directory
- ✅ Updated `_setup_cleanup_logger()` to use `os.environ.get('APP_SERVICE_NAME', 'rampe')` for log directory
- ✅ Updated main logging config to use `os.environ.get('APP_SERVICE_NAME', 'rampe')` for log directory
- **Before:** `/var/log/app_item_listing_tool/app.log`
- **After:** `/var/log/{app_name}/app.log` (dynamic based on APP_SERVICE_NAME env var)

#### app/services/cloudwatch_service.py
- ✅ Updated CloudWatch namespace from hardcoded `'AppItemListingTool'` to `os.environ.get('CLOUDWATCH_NAMESPACE', 'Rampe')`

#### app/routes/api/ebay.py
- ✅ Updated default EBAY_VERIFICATION_TOKEN from `'app_item_listing_tool-token'` to `'your-verification-token-here'`

#### app/routes/api/ebay_search.py
- ✅ Updated S3 URL security check to use `S3_BUCKET_NAME` environment variable instead of hardcoded app name

#### main.py
- ✅ Updated `restart_application()` function to use `os.environ.get('APP_SERVICE_NAME', 'rampe')` for supervisorctl commands

### 4. Documentation Updates

#### Root Directory:
- ✅ **README.md** - Updated all examples to use `<app_name>` or `rampe` instead of `app_item_listing_tool`
- ✅ **.gitignore** - Updated comments about venv location

#### instance/
- ✅ **instance/README.md** - Updated all paths and examples to use `<app_name>` placeholder
  - Updated default from `app_item_listing_tool` to `rampe`
  - Fixed all example commands to use generic placeholders
  - Updated cron jobs to use `~/.venv/bin/python` (venv in home)

#### app/
- ✅ **app/SECURITY.md** - Updated log paths to use `<app_name>` placeholder

#### deployment/
- ✅ **deployment/SECRET_MANAGEMENT.md** - Updated all secret names to use `<app_name>/production`
- ✅ **deployment/DEPLOYMENT_COMPLETE_GUIDE.md** - Updated all references to use generic placeholders
- ✅ **deployment/DEVELOPMENT_NOTES.md** - Updated CloudWatch namespace reference
- ✅ **deployment/scripts/secret-migrate-to-vault.sh** - Updated default instance name to `rampe`
- ✅ **deployment/scripts/infra-complete-setup.sh** - Updated default instance name to `rampe`
- ✅ **deployment/scripts/setup-monitoring.sh** - Updated CloudWatch namespace to use variable

## Environment Variables Added

These are now set automatically by the deployment:

1. **APP_SERVICE_NAME** - Service name for supervisorctl/systemd (e.g., "rampe")
2. **CLOUDWATCH_NAMESPACE** - CloudWatch metrics namespace (e.g., "Rampe")

Both are configured in `deployment/templates/env.j2` from the `all.yml` variables.

## Virtual Environment Location Change

### Before:
- Development: `<project>/.venv/`
- Production: `<project>/.venv/`

### After:
- Development: `<project>/.venv/` (unchanged)
- Production: `/home/ubuntu/.venv/` (in user's home directory, outside project)

**Benefits:**
- Cleaner project directory
- Easier to wipe and redeploy project without recreating venv
- Standard practice for production deployments
- Configured in `deployment/group_vars/all.yml` as `venv_dir`

## How to Rename Your App

To rename the application, edit **one file**: `deployment/group_vars/all.yml`

```yaml
app_name: your_app_name                      # Technical name (paths, services)
app_display_name: "Your App Name"            # Display name (UI, CloudWatch)
app_url: "https://github.com/yourusername/your_app_name"
```

This automatically updates:
- Service names (systemd/supervisor)
- Log directories (`/var/log/your_app_name/`)
- Application directory (`/home/ubuntu/your_app_name/`)
- AWS Secrets Manager secret name (`your_app_name/production`)
- CloudWatch metrics namespace
- All deployment paths and configurations

## Remaining Documentation References

Some documentation files (like OPERATIONS.md) may still contain example commands with "app_item_listing_tool" - these are acceptable as examples in documentation and would be replaced by users following the guides with their actual app name from `all.yml`.

## Testing Checklist

Before deploying:
- [ ] Verify `deployment/group_vars/all.yml` has correct `app_name`
- [ ] Verify `venv_dir` is set to `/home/{{ app_user }}/.venv`
- [ ] Check that secrets are properly configured in vault
- [ ] Test that deployment creates correct directory structure
- [ ] Verify services start with correct names
- [ ] Check logs are written to `/var/log/<app_name>/`
- [ ] Confirm CloudWatch metrics use correct namespace

## Migration Notes

If migrating from an existing deployment:
1. Old logs may still be at `/var/log/app_item_listing_tool/`
2. Old venv may still be at `<project>/.venv/`
3. Consider running a cleanup/migration script to consolidate
4. Update any external references (monitoring, alerts, etc.)

