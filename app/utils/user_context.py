"""
User context utilities for multi-user support.

Provides functions to get user-specific file paths and settings.
Each user has their own CSV file, SKU counter, and can optionally
have their own eBay API credentials.
"""
from pathlib import Path
from flask import session, current_app, has_request_context
import os


def get_current_username():
    """
    Get the current logged-in username from session.

    Returns:
        str: The username, or 'default' if not logged in or outside request context
    """
    if not has_request_context():
        return 'default'
    return session.get('username', 'default')


def get_user_csv_file(username=None):
    """
    Get the CSV file path for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's items CSV file (e.g., instance/data/brian-items.csv)
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses items.csv
    if username == 'default':
        return Path(current_app.config['CSV_FILE'])

    # Multi-user: username-items.csv in data subdirectory
    base_dir = Path(current_app.config['CSV_FILE']).parent
    data_dir = base_dir / 'data'
    data_dir.mkdir(exist_ok=True)

    return data_dir / f"{username}-items.csv"


def get_user_sku_file(username=None):
    """
    Get the SKU counter file path for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's SKU counter file (e.g., instance/data/brian-sku.txt)
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses sku.txt
    if username == 'default':
        return Path(current_app.config['SKU_FILE'])

    # Multi-user: username-sku.txt in data subdirectory
    base_dir = Path(current_app.config['SKU_FILE']).parent
    data_dir = base_dir / 'data'
    data_dir.mkdir(exist_ok=True)

    return data_dir / f"{username}-sku.txt"


def get_user_secret_name(username=None):
    """
    Get the AWS Secrets Manager secret name for a user's eBay credentials.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        str: Secret name (e.g., 'rampe/users/brian' or 'rampe/production')
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses app-level secret
    if username == 'default':
        app_name = os.environ.get('APP_NAME', 'app-item-listing-tool')
        return os.environ.get('SECRET_NAME', f'{app_name}/production')

    # Multi-user: {app_prefix}/users/{username}
    # Keeps user secrets under the same IAM policy prefix as the main app secret
    secret_name = os.environ.get('SECRET_NAME', 'rampe/production')
    prefix = secret_name.split('/')[0]
    return f"{prefix}/users/{username}"


def get_ebay_credentials(username=None):
    """
    Get eBay API credentials for a specific user.

    Tries to load user-specific credentials from AWS Secrets Manager.
    Falls back to app-level credentials if user-specific ones don't exist.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        dict: eBay credentials or None if not found
    """
    from app.config import get_secret

    if username is None:
        username = get_current_username()

    # Try user-specific secret first using the new service
    if username != 'default':
        try:
            from app.services.user_secrets_service import user_secrets_service
            user_creds = user_secrets_service.get_user_ebay_credentials(username)
            if user_creds:
                return user_creds
        except Exception as e:
            current_app.logger.warning(f"Could not fetch user-specific eBay credentials for {username}: {e}")

    # Fall back to app-level credentials (from main secret)
    return {
        'EBAY_PRODUCTION_APP_ID': get_secret('EBAY_PRODUCTION_APP_ID'),
        'EBAY_PRODUCTION_CERT_ID': get_secret('EBAY_PRODUCTION_CERT_ID'),
        'EBAY_PRODUCTION_DEV_ID': get_secret('EBAY_PRODUCTION_DEV_ID'),
        'EBAY_PRODUCTION_TOKEN': get_secret('EBAY_PRODUCTION_TOKEN'),
        'EBAY_SANDBOX_APP_ID': get_secret('EBAY_SANDBOX_APP_ID'),
        'EBAY_SANDBOX_CERT_ID': get_secret('EBAY_SANDBOX_CERT_ID'),
        'EBAY_SANDBOX_DEV_ID': get_secret('EBAY_SANDBOX_DEV_ID'),
        'EBAY_SANDBOX_TOKEN': get_secret('EBAY_SANDBOX_TOKEN'),
    }


def get_user_s3_prefix(username=None):
    """
    Get the S3 prefix (folder) for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        str: S3 prefix (e.g., 'users/brian/' or 'users/sarah/')
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses root/production prefix
    if username == 'default':
        s3_folder = os.environ.get('S3_FOLDER', 'production')
        return f"{s3_folder}/"

    # Multi-user: users/{username}/
    return f"users/{username}/"


def get_user_s3_images_prefix(username=None):
    """
    Get the S3 prefix for user's images.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        str: S3 images prefix (e.g., 'users/brian/images/')
    """
    base_prefix = get_user_s3_prefix(username)
    return f"{base_prefix}images/"


def get_user_s3_backups_prefix(username=None):
    """
    Get the S3 prefix for user's backups.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        str: S3 backups prefix (e.g., 'users/brian/backups/')
    """
    base_prefix = get_user_s3_prefix(username)
    return f"{base_prefix}backups/"


def get_user_s3_exports_prefix(username=None):
    """
    Get the S3 prefix for user's exports.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        str: S3 exports prefix (e.g., 'users/brian/exports/')
    """
    base_prefix = get_user_s3_prefix(username)
    return f"{base_prefix}exports/"


def get_user_snapshots_dir(username=None):
    """
    Get the local snapshots directory for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's snapshots directory
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses root snapshots
    if username == 'default':
        csv_file = Path(current_app.config['CSV_FILE'])
        return csv_file.parent / 'snapshots'

    # Multi-user: instance/data/{username}/snapshots/
    csv_file = Path(current_app.config['CSV_FILE'])
    base_dir = csv_file.parent / 'data' / username
    base_dir.mkdir(exist_ok=True, parents=True)

    snapshots_dir = base_dir / 'snapshots'
    snapshots_dir.mkdir(exist_ok=True, parents=True)
    return snapshots_dir


def get_user_trash_dir(username=None):
    """
    Get the local trash directory for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's trash directory
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses root trash
    if username == 'default':
        csv_file = Path(current_app.config['CSV_FILE'])
        return csv_file.parent / 'trash'

    # Multi-user: instance/data/{username}/trash/
    csv_file = Path(current_app.config['CSV_FILE'])
    base_dir = csv_file.parent / 'data' / username
    base_dir.mkdir(exist_ok=True, parents=True)

    trash_dir = base_dir / 'trash'
    trash_dir.mkdir(exist_ok=True, parents=True)
    return trash_dir


def get_user_analytics_dir(username=None):
    """
    Get the local analytics directory for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's analytics directory
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses root analytics
    if username == 'default':
        csv_file = Path(current_app.config['CSV_FILE'])
        return csv_file.parent / 'analytics'

    # Multi-user: instance/data/{username}/analytics/
    csv_file = Path(current_app.config['CSV_FILE'])
    base_dir = csv_file.parent / 'data' / username
    base_dir.mkdir(exist_ok=True, parents=True)

    analytics_dir = base_dir / 'analytics'
    analytics_dir.mkdir(exist_ok=True, parents=True)
    return analytics_dir


def get_user_exports_dir(username=None):
    """
    Get the local exports directory for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's exports directory
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses root exports
    if username == 'default':
        csv_file = Path(current_app.config['CSV_FILE'])
        return csv_file.parent / 'exports'

    # Multi-user: instance/data/{username}/exports/
    csv_file = Path(current_app.config['CSV_FILE'])
    base_dir = csv_file.parent / 'data' / username
    base_dir.mkdir(exist_ok=True, parents=True)

    exports_dir = base_dir / 'exports'
    exports_dir.mkdir(exist_ok=True, parents=True)
    return exports_dir


def get_user_uploads_dir(username=None):
    """
    Get the local uploads directory for a specific user.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's uploads directory (temporary files)
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses root uploads
    if username == 'default':
        csv_file = Path(current_app.config['CSV_FILE'])
        return csv_file.parent / 'uploads'

    # Multi-user: instance/data/{username}/uploads/
    csv_file = Path(current_app.config['CSV_FILE'])
    base_dir = csv_file.parent / 'data' / username
    base_dir.mkdir(exist_ok=True, parents=True)

    uploads_dir = base_dir / 'uploads'
    uploads_dir.mkdir(exist_ok=True, parents=True)
    return uploads_dir


def get_user_images_dir(username=None):
    """
    Get the local images directory for a specific user (if not using S3).

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        Path: Path to user's local images directory
    """
    if username is None:
        username = get_current_username()

    # For backward compatibility, 'default' user uses root images
    if username == 'default':
        csv_file = Path(current_app.config['CSV_FILE'])
        return csv_file.parent / 'images'

    # Multi-user: instance/data/{username}/images/
    csv_file = Path(current_app.config['CSV_FILE'])
    base_dir = csv_file.parent / 'data' / username
    base_dir.mkdir(exist_ok=True, parents=True)

    images_dir = base_dir / 'images'
    images_dir.mkdir(exist_ok=True, parents=True)
    return images_dir


def get_user_s3_snapshots_prefix(username=None):
    """
    Get the S3 prefix for user's snapshots.

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        str: S3 snapshots prefix (e.g., 'users/brian/snapshots/')
    """
    base_prefix = get_user_s3_prefix(username)
    return f"{base_prefix}snapshots/"


def get_user_s3_trash_prefix(username=None):
    """
    Get the S3 prefix for user's trash (deleted items).

    Args:
        username (str, optional): Username. If None, uses current session user.

    Returns:
        str: S3 trash prefix (e.g., 'users/brian/trash/')
    """
    base_prefix = get_user_s3_prefix(username)
    return f"{base_prefix}trash/"


def ensure_user_data_directory():
    """
    Ensure the user data directory exists.

    Creates instance/data/ if it doesn't exist.
    """
    csv_file = Path(current_app.config['CSV_FILE'])
    data_dir = csv_file.parent / 'data'
    data_dir.mkdir(exist_ok=True, parents=True)

