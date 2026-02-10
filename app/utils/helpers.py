"""Utility helper functions for common tasks."""
import time
import secrets
from pathlib import Path
from flask import session
from werkzeug.utils import secure_filename


def generate_unique_filename(original_filename):
    """
    Create a unique filename by appending a timestamp to the base name.

    This ensures that multiple uploads of files with the same name don't
    overwrite each other. Sanitizes the original filename to prevent
    directory traversal attacks or invalid character issues.

    Args:
        original_filename (str): The original filename provided by the user.

    Returns:
        str: A unique filename with timestamp appended before the extension.
    """
    # Get current time in milliseconds for uniqueness
    timestamp = str(int(time.time() * 1000))
    # Sanitize the filename to prevent security issues
    filename = secure_filename(original_filename)
    # Split into name and extension
    name, ext = filename.rsplit('.', 1) if '.' in filename else (filename, '')
    # Append timestamp before extension
    return f"{name}_{timestamp}.{ext}" if ext else f"{name}_{timestamp}"


def get_directory_size(path):
    """
    Calculate the total size of all files in a directory.

    Recursively walks the directory tree and sums the size of all files.
    Returns 0 if the directory doesn't exist or is inaccessible.

    Args:
        path (str or Path): Path to the directory to measure.

    Returns:
        int: Total size in bytes.
    """
    path = Path(path)
    total = 0
    try:
        # Check if path exists and is a directory
        if path.exists() and path.is_dir():
            # Recursively iterate through all files
            for item in path.rglob('*'):
                # Only count files, not directories
                if item.is_file():
                    total += item.stat().st_size
    except Exception:
        # Silently return 0 if any error occurs (e.g., permission denied)
        pass
    return total


def generate_csrf_token():
    """
    Generate and store a CSRF token in the user's session.

    If a token already exists in the session, returns that token.
    Otherwise, generates a new cryptographically secure token and stores it.

    Returns:
        str: The CSRF token (existing or newly generated).
    """
    # Check if token already exists in session
    if '_csrf_token' not in session:
        # Generate new secure token using secrets module
        session['_csrf_token'] = secrets.token_hex(32)
    return session['_csrf_token']
