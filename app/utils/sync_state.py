"""
Sync state management for backup synchronization.
Tracks the progress and status of S3 to local backup sync.
"""
import threading
from datetime import datetime
from typing import Optional, Dict


class SyncState:
    """Thread-safe singleton for tracking backup sync state."""

    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        """Implement singleton pattern for SyncState."""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialize()
        return cls._instance

    def _initialize(self):
        """Initialize the sync state."""
        self._state_lock = threading.Lock()
        self.status = 'not_started'  # not_started, in_progress, synchronized, failed
        self.total_backups = 0
        self.completed_backups = 0
        self.current_backup = None
        self.error_message = None
        self.started_at = None
        self.completed_at = None
        self.is_app_locked = False  # Lock app operations during sync
        self.retry_count = 0  # Current retry attempt
        self.max_retries = 3  # Maximum retry attempts per backup

    def start_sync(self, total_backups: int):
        """Mark sync as started."""
        with self._state_lock:
            self.status = 'in_progress'
            self.total_backups = total_backups
            self.completed_backups = 0
            self.current_backup = None
            self.error_message = None
            self.started_at = datetime.utcnow()
            self.completed_at = None
            self.is_app_locked = True  # Lock app during sync
            self.retry_count = 0

    def update_progress(self, completed: int, current_backup: Optional[str] = None, retry_count: int = 0):
        """Update sync progress."""
        with self._state_lock:
            self.completed_backups = completed
            self.current_backup = current_backup
            self.retry_count = retry_count

    def complete_sync(self):
        """Mark sync as successfully completed."""
        with self._state_lock:
            self.status = 'synchronized'
            self.completed_at = datetime.utcnow()
            self.current_backup = None
            self.is_app_locked = False  # Unlock app

    def fail_sync(self, error_message: str):
        """Mark sync as failed."""
        with self._state_lock:
            self.status = 'failed'
            self.error_message = error_message
            self.completed_at = datetime.utcnow()
            self.is_app_locked = False  # Unlock app even on failure

    def get_state(self) -> Dict:
        """Get current sync state as dictionary."""
        with self._state_lock:
            return {
                'status': self.status,
                'total_backups': self.total_backups,
                'completed_backups': self.completed_backups,
                'current_backup': self.current_backup,
                'error_message': self.error_message,
                'started_at': self.started_at.isoformat() if self.started_at else None,
                'completed_at': self.completed_at.isoformat() if self.completed_at else None,
                'is_app_locked': self.is_app_locked,
                'progress_percent': int((self.completed_backups / self.total_backups * 100)) if self.total_backups > 0 else 0,
                'retry_count': self.retry_count,
                'max_retries': self.max_retries
            }

    def is_locked(self) -> bool:
        """Check if app operations should be locked."""
        with self._state_lock:
            return self.is_app_locked

    def lock_sync(self):
        """Acquire sync lock to prevent concurrent syncs across workers."""
        with self._state_lock:
            self.is_app_locked = True

    def unlock_sync(self):
        """Release sync lock to allow other processes to sync."""
        with self._state_lock:
            self.is_app_locked = False


# Singleton instance
sync_state = SyncState()
