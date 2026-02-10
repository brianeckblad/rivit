"""Flask application factory."""
from flask import Flask, has_request_context, g
import os
from dotenv import load_dotenv
from pathlib import Path
import logging
from logging.handlers import RotatingFileHandler
import time
import json

# Track application start time
APP_START_TIME = time.time()

# Load environment variables from .env file
# Use explicit path to ensure it's found regardless of working directory
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(dotenv_path=env_path)


class UserContextFilter(logging.Filter):
    """
    Logging filter that adds the current username to log records.
    
    This filter checks if a request context is available and attempts to
    retrieve the username from Flask's 'g' object. If no user is logged in
    or if called outside a request context, it defaults to 'anonymous'
    or 'system'.
    """
    def filter(self, record):
        """
        Add username attribute to the log record.
        
        Args:
            record: The log record to be filtered.
            
        Returns:
            bool: Always True to allow the record to be logged.
        """
        if has_request_context():
            # Try to get username from g (set by login_required decorator)
            record.username = getattr(g, 'username', 'anonymous')
        else:
            record.username = 'system'
        return True


def _setup_service_logger(app, config_name):
    """
    Setup a dedicated logger for service operations (S3 sync, health checks, etc).

    In production: Creates /var/log/app_item_listing_tool/service.log
    In development: Creates instance/service.log

    Args:
        app: Flask application instance
        config_name: Current configuration name
    """
    try:
        # Determine log path based on environment
        if config_name == 'production':
            log_dir = Path('/var/log/app_item_listing_tool')
        else:
            log_dir = Path(app.instance_path)

        service_log_path = log_dir / 'service.log'
        service_log_path.parent.mkdir(parents=True, exist_ok=True)

        # Create service logger
        service_logger = logging.getLogger('service')
        service_logger.setLevel(logging.DEBUG)
        service_logger.propagate = False  # Prevent propagation to root logger

        # Remove any existing handlers
        service_logger.handlers = []

        # Create rotating file handler for service.log
        service_handler = RotatingFileHandler(
            str(service_log_path),
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=10
        )
        service_handler.setLevel(logging.DEBUG)
        service_handler.setFormatter(logging.Formatter(
            '[%(asctime)s] %(levelname)s in %(name)s: %(message)s'
        ))

        service_logger.addHandler(service_handler)

        # Store reference on app for easy access
        app.service_logger = service_logger

    except Exception as e:
        app.logger.warning(f"Could not set up service logger: {e}")


def _setup_cleanup_logger(app, config_name):
    """
    Setup a dedicated logger for cleanup operations (health checks, trash cleanup, orphaned files).

    In production: Creates /var/log/app_item_listing_tool/cleanup.log
    In development: Creates instance/cleanup.log

    Args:
        app: Flask application instance
        config_name: Current configuration name
    """
    try:
        # Determine log path based on environment
        if config_name == 'production':
            log_dir = Path('/var/log/app_item_listing_tool')
        else:
            log_dir = Path(app.instance_path)

        cleanup_log_path = log_dir / 'cleanup.log'
        cleanup_log_path.parent.mkdir(parents=True, exist_ok=True)

        # Create cleanup logger
        cleanup_logger = logging.getLogger('cleanup')
        cleanup_logger.setLevel(logging.DEBUG)
        cleanup_logger.propagate = False  # Prevent propagation to root logger

        # Remove any existing handlers
        cleanup_logger.handlers = []

        # Create rotating file handler for cleanup.log
        cleanup_handler = RotatingFileHandler(
            str(cleanup_log_path),
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=10
        )
        cleanup_handler.setLevel(logging.DEBUG)
        cleanup_handler.setFormatter(logging.Formatter(
            '[%(asctime)s] %(levelname)s in %(name)s: %(message)s'
        ))

        cleanup_logger.addHandler(cleanup_handler)

        # Store reference on app for easy access
        app.cleanup_logger = cleanup_logger

    except Exception as e:
        app.logger.warning(f"Could not set up cleanup logger: {e}")


def create_app(config_name='development'):
    """
    Flask application factory.
    
    This function initializes the Flask application, loads configuration,
    sets up logging, ensures required directories exist, synchronizes
    initial state from S3, and registers blueprints and background tasks.
    
    Args:
        config_name (str): The configuration environment to use 
                          ('development', 'production', or 'testing').
                          Defaults to 'development'.
                          
    Returns:
        Flask: The configured Flask application instance.
    """
    # Use standard Flask structure (static/ and templates/ in app/ folder)
    # Flask automatically looks for these folders in the same directory as __init__.py
    app = Flask(__name__)

    # Load configuration
    from app.config import config
    app.config.from_object(config[config_name])

    # Configure logging
    if config_name == 'production':
        # In production, try to log to /var/log/app_item_listing_tool/app.log
        # The directory should be created by deployment scripts
        try:
            log_file = Path('/var/log/app_item_listing_tool/app.log')

            # Only set up file logging if directory exists and is writable
            if log_file.parent.exists() and os.access(log_file.parent, os.W_OK):
                file_handler = RotatingFileHandler(
                    str(log_file),
                    maxBytes=10 * 1024 * 1024,  # 10MB
                    backupCount=10
                )
                file_handler.setLevel(logging.INFO)
                file_handler.setFormatter(logging.Formatter(
                    '[%(asctime)s] %(username)s - %(levelname)s in %(module)s: %(message)s'
                ))
                file_handler.addFilter(UserContextFilter())
                app.logger.addHandler(file_handler)
                app.logger.setLevel(logging.INFO)
                app.logger.propagate = False  # Prevent propagation to gunicorn's logger
                app.logger.addFilter(UserContextFilter())
            else:
                # Just use default logging to stderr/stdout (captured by supervisor)
                app.logger.setLevel(logging.INFO)
                app.logger.propagate = False
        except Exception as e:
            # Fallback to stderr if can't create log file
            print(f"Warning: Could not set up file logging: {e}", flush=True)
            app.logger.setLevel(logging.INFO)
    else:
        # In development, log to console AND file for consistency
        app.logger.setLevel(logging.DEBUG)

        # Also write to instance/app.log for easier debugging
        try:
            dev_log_file = Path(app.instance_path) / 'app.log'
            dev_log_file.parent.mkdir(parents=True, exist_ok=True)

            dev_file_handler = RotatingFileHandler(
                str(dev_log_file),
                maxBytes=10 * 1024 * 1024,  # 10MB
                backupCount=5
            )
            dev_file_handler.setLevel(logging.DEBUG)
            dev_file_handler.setFormatter(logging.Formatter(
                '[%(asctime)s] %(username)s - %(levelname)s in %(module)s: %(message)s'
            ))
            dev_file_handler.addFilter(UserContextFilter())
            app.logger.addHandler(dev_file_handler)
        except Exception as e:
            print(f"Warning: Could not set up development file logging: {e}", flush=True)

    # Configure service logger (for S3 sync, health checks, etc.)
    _setup_service_logger(app, config_name)
    # Configure cleanup logger (for health checks, trash cleanup, orphaned files)
    _setup_cleanup_logger(app, config_name)

    # Initialize security middleware (DDoS protection, attack detection, rate limiting)
    from app.security import init_security_middleware
    init_security_middleware(app)

    # Use SECRET_KEY from config (loaded from .env file)
    # All workers must use the same SECRET_KEY for sessions to work with Gunicorn

    # Ensure required directories exist
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(os.path.dirname(app.config['CSV_FILE']), exist_ok=True)
    os.makedirs(os.path.dirname(app.config['SKU_FILE']), exist_ok=True)

    # Create multi-user data directory for user-specific CSV and SKU files
    data_dir = os.path.join(os.path.dirname(app.config['CSV_FILE']), 'data')
    os.makedirs(data_dir, exist_ok=True)
    app.logger.info(f"Multi-user data directory ensured: {data_dir}")

    # Sync SKU, CSV, and User Preferences from S3 on startup BEFORE initializing users
    from app.services.s3_service import s3_service
    from datetime import timezone
    sku_file = Path(app.config['SKU_FILE'])
    csv_file = Path(app.config['CSV_FILE'])

    # 1. Sync SKU
    local_sku = None
    local_sku_mtime = None
    if sku_file.exists() and sku_file.stat().st_size > 0:
        try:
            local_sku_mtime = sku_file.stat().st_mtime
            with open(sku_file, 'r') as f:
                local_sku = int(f.read().strip())
        except (ValueError, IOError):
            local_sku = None

    sku_data_from_s3 = s3_service.restore_sku_from_s3()

    final_sku = None
    sku_source = None

    # Determine which SKU to use. Always use the highest value to prevent
    # duplicate SKUs across multiple instances. Modification time is ignored -
    # only the numeric value matters for consistency.
    if sku_data_from_s3 and local_sku:
        s3_sku = sku_data_from_s3['sku']
        if s3_sku > local_sku:
            final_sku = s3_sku
            sku_source = f'S3 (higher: {s3_sku} vs local: {local_sku})'
        else:
            final_sku = local_sku
            sku_source = f'local (higher: {local_sku} vs S3: {s3_sku})'
            # Upload local SKU to S3 when local is higher
            if local_sku > s3_sku:
                s3_service.backup_sku_to_s3(local_sku)
    elif sku_data_from_s3:
        final_sku = sku_data_from_s3['sku']
        sku_source = 'S3'
    elif local_sku:
        final_sku = local_sku
        sku_source = 'local'
        # Upload local SKU to S3 when S3 is missing it
        s3_service.backup_sku_to_s3(local_sku)
    else:
        final_sku = 1000
        sku_source = 'default'

    if local_sku != final_sku:
        sku_file.parent.mkdir(parents=True, exist_ok=True)
        with open(sku_file, 'w') as f:
            f.write(f"{final_sku}\n")

    # 2. Sync Main CSV Inventory
    local_csv_mtime = None
    local_csv_size = 0
    if csv_file.exists():
        local_csv_mtime = csv_file.stat().st_mtime
        local_csv_size = csv_file.stat().st_size

    csv_data_from_s3 = s3_service.restore_main_csv_from_s3()

    if csv_data_from_s3:
        s3_csv_mtime = csv_data_from_s3['last_modified'].replace(tzinfo=timezone.utc).timestamp()

        if not local_csv_mtime:
            # Local doesn't exist - download from S3
            csv_file.parent.mkdir(parents=True, exist_ok=True)
            with open(csv_file, 'wb') as f:
                f.write(csv_data_from_s3['content'])
        elif s3_csv_mtime > local_csv_mtime:
            # S3 is newer - download from S3
            csv_file.parent.mkdir(parents=True, exist_ok=True)
            with open(csv_file, 'wb') as f:
                f.write(csv_data_from_s3['content'])
        elif local_csv_mtime > s3_csv_mtime and local_csv_size > 300:
            # Local is newer AND has real data - upload to S3
            s3_service.backup_main_csv_to_s3(csv_file)
        elif local_csv_mtime > s3_csv_mtime and local_csv_size <= 300:
            # Local is newer but only has header - download from S3 instead
            csv_file.parent.mkdir(parents=True, exist_ok=True)
            with open(csv_file, 'wb') as f:
                f.write(csv_data_from_s3['content'])
    else:
        # S3 is missing the CSV - upload local if it exists and is valid
        if csv_file.exists() and local_csv_size > 300:  # More than just header
            s3_service.backup_main_csv_to_s3(csv_file)

    # Initialize CSV file with headers if it still doesn't exist (after S3 sync attempt)
    from app.services.csv_service import initialize_csv
    initialize_csv(app.config['CSV_FILE'])

    # 3. Sync User Preferences (with extra safety for user-created accounts)
    user_prefs_file = Path(app.instance_path) / 'user_preferences.json'
    local_prefs_mtime = None
    local_user_count = 0

    # Check local file status
    if user_prefs_file.exists():
        local_prefs_mtime = user_prefs_file.stat().st_mtime
        try:
            with open(user_prefs_file, 'r') as f:
                local_prefs = json.load(f)
                local_user_count = len(local_prefs)
        except:
            local_user_count = 0

    prefs_data_from_s3 = s3_service.restore_user_preferences_from_s3()

    if prefs_data_from_s3:
        s3_prefs_mtime = prefs_data_from_s3['last_modified'].replace(tzinfo=timezone.utc).timestamp()
        s3_user_count = len(prefs_data_from_s3['content'])

        if not local_prefs_mtime:
            # Local doesn't exist - download from S3
            app.logger.info(f"📥 Downloading user preferences from S3 ({s3_user_count} users)")
            user_prefs_file.parent.mkdir(parents=True, exist_ok=True)
            with open(user_prefs_file, 'w') as f:
                json.dump(prefs_data_from_s3['content'], f, indent=2)
        elif s3_prefs_mtime > local_prefs_mtime:
            # S3 is newer - but check if local has more users (safety check)
            if local_user_count > s3_user_count and local_user_count > 1:
                app.logger.warning(f"⚠️  S3 has newer timestamp but local has more users ({local_user_count} vs {s3_user_count})")
                app.logger.warning(f"⚠️  Keeping local users and uploading to S3 instead")
                s3_service.backup_user_preferences_to_s3(user_prefs_file)
            else:
                # Safe to download from S3
                app.logger.info(f"📥 S3 user preferences newer - downloading ({s3_user_count} users)")
                user_prefs_file.parent.mkdir(parents=True, exist_ok=True)
                with open(user_prefs_file, 'w') as f:
                    json.dump(prefs_data_from_s3['content'], f, indent=2)
        elif local_prefs_mtime > s3_prefs_mtime:
            # Local is newer - upload to S3
            app.logger.info(f"📤 Local user preferences newer - uploading to S3 ({local_user_count} users)")
            s3_service.backup_user_preferences_to_s3(user_prefs_file)
        else:
            # Same timestamp - no sync needed
            app.logger.info(f"✅ User preferences in sync ({local_user_count} users)")
    else:
        # S3 is missing the user preferences - upload local if it exists
        if user_prefs_file.exists():
            app.logger.info(f"📤 No S3 user preferences found - uploading local ({local_user_count} users)")
            s3_service.backup_user_preferences_to_s3(user_prefs_file)
        else:
            app.logger.info("ℹ️  No user preferences found locally or in S3 - will create on first login")

    # Initialize user authentication system AFTER S3 sync to ensure clean data
    from app.models.user import user_manager
    with app.app_context():
        users = user_manager._load_users()
        user_count = len(users)
        if user_count > 0:
            usernames = [user['username'] for user in users.values()]
            app.logger.info(f"✅ User authentication initialized with {user_count} user(s): {', '.join(usernames)}")
        else:
            app.logger.warning("⚠️  No users found - create users via web interface or set USERS environment variable")

    # Cleanup expired trash items on startup
    with app.app_context():
        from app.services.trash_service import trash_service
        try:
            trash_service.cleanup_expired()
        except Exception as e:
            app.logger.error(f"Error cleaning up trash on startup: {e}")

    # Sync backups from S3 to local storage on startup (in background thread)
    # NOTE: Health check runs AFTER sync to ensure local images exist first
    import threading
    from app.utils.sync_state import sync_state

    def sync_backups_background():
        """
        Background thread function to sync backups and images from S3.
        
        This function handles bi-directional synchronization of images and exports
        between the local instance directory and the S3 bucket. It prevents multiple
        concurrent syncs and respects the SKIP_S3_SYNC configuration setting.

        After sync completes, runs a health check to verify CSV integrity and
        delete orphaned images that aren't referenced in the CSV.
        """
        # Check if sync is disabled by configuration
        if app.config.get('SKIP_S3_SYNC', False):
            return

        with app.app_context():
            try:
                # Ensure INSTANCE_PATH is absolute
                instance_abs_path = os.path.abspath(app.instance_path)
                os.environ['INSTANCE_PATH'] = instance_abs_path

                # Check for sync lock FIRST (works across processes)
                if sync_state.is_locked():
                    return

                # Acquire lock to prevent other workers from syncing
                sync_state.lock_sync()

                # 1. Sync Images (Bi-directional)
                img_summary = s3_service.sync_images_from_s3()

                # 2. Sync Exports (Bi-directional)
                exp_summary = s3_service.sync_exports_from_s3()

                # 3. Run health check AFTER sync completes
                # This ensures local images are downloaded from S3 before checking for orphans
                # Health check now supports multi-user by checking all CSV files
                from app.services.health_check_service import HealthCheckService
                try:
                    health_check = HealthCheckService(instance_path=app.instance_path)
                    results = health_check.run()
                    if results['success']:
                        app.service_logger.info(
                            f"✓ Health check passed - "
                            f"Users checked: {results['users_checked']}, "
                            f"S3 orphans deleted: {results['orphaned_s3_deleted']}, "
                            f"Local orphans deleted: {results['orphaned_local_deleted']}"
                        )
                    else:
                        app.logger.warning(f"Health check completed with errors: {results['errors']}")
                except Exception as health_err:
                    app.logger.error(f"Error running health check after sync: {health_err}")

            except Exception as e:
                app.logger.error(f"Error in background sync: {e}")
                sync_state.fail_sync(str(e))
            finally:
                # Release the lock so other processes can sync later if needed
                sync_state.unlock_sync()

    # Start backup sync in background thread
    sync_thread = threading.Thread(target=sync_backups_background, daemon=True)
    sync_thread.start()

    # Register blueprints
    from app.routes.auth import auth_bp
    from app.routes.main import main_bp
    from app.routes.api import api_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)
    app.register_blueprint(api_bp, url_prefix='/api')

    # Register template globals
    from app.utils.helpers import generate_csrf_token
    app.jinja_env.globals['csrf_token'] = generate_csrf_token

    # Initialize cache for eBay listings
    app.ebay_cache = {}
    app.logger.info("✓ eBay listings cache initialized")

    # Initialize eBay category cache (must run within app context)
    try:
        with app.app_context():
            from app.services.ebay_service import ebay_service
            ebay_service.initialize_category_cache()
            app.logger.info("✓ eBay category cache initialized")
    except Exception as e:
        app.logger.warning(f"⚠ Failed to initialize eBay category cache: {e}")
        import traceback
        app.logger.debug(traceback.format_exc())

    @app.before_request
    def check_ebay_cache_expiry():
        """Check and clear expired cache entries before each request."""
        from datetime import datetime, timedelta

        expired_keys = []
        for key, data in app.ebay_cache.items():
            try:
                fetched_at = datetime.fromisoformat(data['fetched_at'])
                if datetime.now() - fetched_at > timedelta(hours=1):
                    expired_keys.append(key)
            except (KeyError, ValueError):
                expired_keys.append(key)

        for key in expired_keys:
            app.logger.info(f"Clearing expired eBay cache: {key}")
            del app.ebay_cache[key]

    @app.context_processor

    def inject_version():
        """
        Inject application version information into the Jinja2 template context.

        This processor attempts to determine the version in the following priority:
        1) Read 'instance/app_version' file (generated during deployment).
        2) Query Git for the total commit count on the current branch.
        3) Fall back to 'unavailable' if both methods fail.

        Returns:
            dict: A dictionary containing version details used globally in templates.
        """
        try:
            app_stage = 'Private'

            # 1) Check for an instance/app_version file written by the deployment script
            try:
                version_path = Path(app.instance_path) / 'app_version'
            except Exception:
                # If instance_path is not available for some reason, construct a fallback
                version_path = Path(__file__).parent.parent / 'instance' / 'app_version'

            if version_path.exists():
                try:
                    raw = version_path.read_text(encoding='utf-8').strip()
                    if raw:
                        # If the file contains a simple number, use it as build count
                        if raw.isdigit():
                            commit_count = raw
                            app_version = f'vP.{commit_count}'
                            app_version_display = f'{app_stage} (Build {commit_count})'
                        else:
                            # Allow other strings (e.g. 'unknown') to be displayed safely
                            commit_count = raw
                            app_version = f'vP.{commit_count}'
                            app_version_display = f'{app_stage} (Build {commit_count})'

                        return {
                            'app_version': app_version,
                            'app_stage': app_stage,
                            'app_version_display': app_version_display
                        }
                except Exception as e:
                    pass

            # 2) Fallback: try to compute from git commit count (may not be available at runtime)
            try:
                import subprocess
                commit_count = subprocess.check_output(
                    ['git', 'rev-list', '--count', 'HEAD'],
                    cwd=Path(__file__).parent.parent,
                    stderr=subprocess.DEVNULL,
                    timeout=5
                ).decode('utf-8').strip()

                app_version = f'vP.{commit_count}'
                app_version_display = f'{app_stage} (Build {commit_count})'

                return {
                    'app_version': app_version,
                    'app_stage': app_stage,
                    'app_version_display': app_version_display
                }
            except Exception as e:
                pass

            # 3) Give a safe 'unavailable' response
            app_version = 'vP.unavailable'
            app_version_display = f"{app_stage} (Build unavailable)"
            return {
                'app_version': app_version,
                'app_stage': app_stage,
                'app_version_display': app_version_display
            }
        except Exception as e:
            # Very defensive: if something unexpected happens, don't break the app templates
            try:
                app.logger.error(f"Unexpected error when injecting version: {e}")
            except Exception:
                pass
            return {
                'app_version': app_version,
                'app_stage': app_stage,
                'app_version_display': app_version_display
            }

    # Startup Health Check: Validate CSV integrity
    with app.app_context():
        try:
            from app.services.comic_service import comic_service
            comics = comic_service.get_all_comics()
            comic_count = len(comics)

            if comic_count == 0:
                app.logger.warning("⚠️  STARTUP WARNING: CSV file is empty! Mass deletion protection activated.")
                app.logger.warning("   Cleanup operations will be blocked until at least 5 comics are added.")
            elif comic_count < 5:
                app.logger.warning(f"⚠️  STARTUP WARNING: Only {comic_count} comics in CSV - below safety threshold (5)")
                app.logger.warning("   Some cleanup operations may be blocked for safety.")
            else:
                app.logger.info(f"✓ CSV health check passed - {comic_count} comics loaded")
        except Exception as e:
            app.logger.error(f"CSV health check failed on startup: {e}")

    return app


