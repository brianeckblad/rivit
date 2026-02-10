"""Application configuration."""
import os
import json
import boto3
from pathlib import Path
from datetime import timedelta
from botocore.exceptions import ClientError


basedir = Path(__file__).parent.parent


def get_secrets_from_aws():
    """
    Fetch secrets from AWS Secrets Manager.

    Returns dict of secrets or empty dict if unavailable.
    Falls back to environment variables if Secrets Manager is not accessible.
    """
    secret_name = os.environ.get('SECRET_NAME', 'app-item-listing-tool/production')
    region_name = os.environ.get('AWS_REGION', 'us-east-1')

    # Try to fetch from Secrets Manager
    try:
        session = boto3.session.Session()
        client = session.client(
            service_name='secretsmanager',
            region_name=region_name
        )

        response = client.get_secret_value(SecretId=secret_name)

        if 'SecretString' in response:
            return json.loads(response['SecretString'])
        else:
            # Decode binary secret (if stored as binary)
            import base64
            return json.loads(base64.b64decode(response['SecretBinary']))

    except ClientError as e:
        # Secrets Manager not available - fall back to environment variables
        error_code = e.response['Error']['Code']
        if error_code in ['ResourceNotFoundException', 'AccessDeniedException']:
            print(f"Warning: Secrets Manager not available ({error_code}), using environment variables")
            return {}
        else:
            print(f"Warning: Error accessing Secrets Manager: {e}")
            return {}
    except Exception as e:
        print(f"Warning: Unexpected error accessing Secrets Manager: {e}")
        return {}


# Fetch secrets from AWS Secrets Manager (if available)
_secrets = get_secrets_from_aws()


def get_secret(key, default=None):
    """
    Get secret from AWS Secrets Manager or environment variable.

    Priority:
    1. AWS Secrets Manager
    2. Environment variable
    3. Default value
    """
    return _secrets.get(key) or os.environ.get(key) or default


class Config:
    """
    Base configuration class containing default settings.
    
    This class defines common settings used across all environments, 
    including security keys, file paths, upload limits, and service 
    integrations like AWS S3 and eBay.

    Secrets are fetched from AWS Secrets Manager (if available) or
    fall back to environment variables for development.
    """
    # Application identity (configurable)
    APP_NAME = get_secret('APP_NAME', os.environ.get('APP_NAME', 'app-item-listing-tool'))

    SECRET_KEY = get_secret('SECRET_KEY', 'dev-secret-key-change-in-production')

    @classmethod
    def init_app(cls, app):
        """
        Initialize the application with this configuration.
        
        Args:
            app (Flask): The Flask application instance.
        """
        pass

    # Session configuration
    SESSION_COOKIE_SECURE = False  # Set to True when using HTTPS
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    PERMANENT_SESSION_LIFETIME = timedelta(days=1)  # 24 hours

    # File paths
    UPLOAD_FOLDER = basedir / 'instance' / 'uploads'
    CSV_FILE = basedir / 'instance' / 'items.csv'
    SKU_FILE = basedir / 'instance' / 'sku.txt'

    # Upload settings
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max file size
    ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}

    # AWS S3 Configuration
    # Prefer IAM roles (no keys needed in production)
    # Only use explicit keys if provided (for development/local testing)
    AWS_ACCESS_KEY_ID = get_secret('AWS_ACCESS_KEY_ID')  # Optional - IAM role preferred
    AWS_SECRET_ACCESS_KEY = get_secret('AWS_SECRET_ACCESS_KEY')  # Optional - IAM role preferred
    AWS_REGION = get_secret('AWS_REGION', 'us-east-1')
    S3_BUCKET = get_secret('S3_BUCKET_NAME') or get_secret('S3_BUCKET')
    S3_FOLDER = get_secret('S3_FOLDER', 'production')  # Default to production folder

    # CloudFront Configuration (optional - for rate limiting external downloads)
    CLOUDFRONT_DOMAIN = get_secret('CLOUDFRONT_DOMAIN')
    APP_SECRET_TOKEN = get_secret('APP_SECRET_TOKEN')

    # SNS Configuration (optional - for notifications)
    SNS_TOPIC_ARN = get_secret('SNS_TOPIC_ARN')

    # Pagination
    COMICS_PER_PAGE = 20
    MAX_PER_PAGE = 100

    # System Stats Polling (in milliseconds)
    SYSTEM_STATS_INTERVAL = 60000  # 60 seconds

    # eBay Settings
    EBAY_CACHE_TTL = 3600
    EBAY_DAILY_LIMIT = 5000
    EBAY_PRODUCTION_APP_ID = get_secret('EBAY_PRODUCTION_APP_ID')
    EBAY_PRODUCTION_CERT_ID = get_secret('EBAY_PRODUCTION_CERT_ID')
    EBAY_PRODUCTION_DEV_ID = get_secret('EBAY_PRODUCTION_DEV_ID')
    EBAY_PRODUCTION_TOKEN = get_secret('EBAY_PRODUCTION_TOKEN')
    EBAY_SANDBOX_APP_ID = get_secret('EBAY_SANDBOX_APP_ID')
    EBAY_SANDBOX_CERT_ID = get_secret('EBAY_SANDBOX_CERT_ID')
    EBAY_SANDBOX_DEV_ID = get_secret('EBAY_SANDBOX_DEV_ID')
    EBAY_SANDBOX_TOKEN = get_secret('EBAY_SANDBOX_TOKEN')


class DevelopmentConfig(Config):
    """
    Configuration for the development environment.
    
    Enables debug mode, automatic template reloading, and generates
    a unique secret key on each restart to clear active sessions.
    """
    DEBUG = True
    TEMPLATES_AUTO_RELOAD = True
    SEND_FILE_MAX_AGE_DEFAULT = 0
    # Regenerate secret key on each restart in dev mode to clear sessions
    SECRET_KEY = os.urandom(24).hex()


class ProductionConfig(Config):
    """
    Configuration for the production environment.
    
    Disables debug mode, enforces secure session cookies, and
    requires the SECRET_KEY to be explicitly set via environment variables.
    """
    DEBUG = False
    # SESSION_COOKIE_SECURE should be True when using HTTPS
    SESSION_COOKIE_SECURE = True

    @classmethod
    def init_app(cls, app):
        """
        Initialize production-specific application settings.
        
        Args:
            app (Flask): The Flask application instance.
            
        Raises:
            RuntimeError: If SECRET_KEY is not set in the environment.
        """
        if not os.environ.get('SECRET_KEY'):
            raise RuntimeError("SECRET_KEY must be set in production environment!")


config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
