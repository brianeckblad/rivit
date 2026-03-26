"""Analytics routes - Event tracking and analytics management.

This module handles:
- Tracking user events (clicks, page views, etc.)
- Batch event processing
- Analytics data storage

All functions include type hints and comprehensive docstrings for better IDE support.
"""
from flask import request, jsonify, current_app, Response
from app.routes.api import api_bp
import json


@api_bp.route('/analytics/track', methods=['POST'])
def track_analytics_event() -> Response:
    """Receive and store analytics events from frontend.

    Tracks user interactions including page views, button clicks, and other events.
    Supports both single events and batch processing for efficiency.
    No authentication required to track anonymous visitors and logged-out sessions.

    Request Body (JSON):
        Single Event Format:
            {
                "event_type": str,         # e.g., "page_view", "button_click"
                "page": str,               # Current page URL
                "element_id": Optional[str],    # DOM element ID
                "x": Optional[int],        # Mouse X coordinate
                "y": Optional[int],        # Mouse Y coordinate
                "viewport_width": Optional[int],   # Browser width
                "viewport_height": Optional[int],  # Browser height
                "timestamp": Optional[str]  # ISO format timestamp
            }

        Batch Event Format:
            {
                "events": [
                    { ... event 1 ... },
                    { ... event 2 ... }
                ]
            }

    Returns:
        Response: Flask JSON response containing:
            - success (bool): Whether tracking succeeded
            - events_saved (int): Number of events stored
            - error (str, optional): Error message if failed

    Status Codes:
        200: Events successfully tracked
        400: Invalid request data or no events provided
        500: Server error occurred

    Example Request (Single Event):
        {
            "event_type": "page_view",
            "page": "/browse",
            "viewport_width": 1920,
            "viewport_height": 1080
        }

    Example Request (Batch Events):
        {
            "events": [
                {"event_type": "page_view", "page": "/"},
                {"event_type": "button_click", "element_id": "add-comic-btn"}
            ]
        }

    Example Response:
        {
            "success": true,
            "events_saved": 2
        }

    Note:
        - Stores events in instance/analytics/ directory
        - Batching reduces HTTP overhead
        - Failed tracking doesn't interrupt user workflow
        - Accepts events even without proper Content-Type header
    """
    import traceback
    from app.models.analytics import AnalyticsStore, AnalyticsEvent

    try:
        # Try to get JSON data, force=True allows parsing even without proper Content-Type
        data = request.get_json(force=True, silent=True)

        if not data:
            # Fallback: try to parse request.data as JSON
            try:
                data = json.loads(request.data.decode('utf-8'))
            except Exception:
                return jsonify({'success': False, 'error': 'No valid JSON data provided'}), 400

        # Support batch events
        events_data = data.get('events', [])
        if not events_data and data.get('event_type'):
            # Single event format
            events_data = [data]

        if not events_data:
            return jsonify({'success': False, 'error': 'No events provided'}), 400

        # Initialize analytics store with user-specific directory
        from app.utils.user_context import get_user_analytics_dir, get_current_username
        username = get_current_username()
        analytics_dir = str(get_user_analytics_dir())
        store = AnalyticsStore(analytics_dir)

        # Convert to AnalyticsEvent objects
        events = []
        for event_data in events_data:
            event = AnalyticsEvent(
                event_type=event_data.get('event_type'),
                page=event_data.get('page'),
                element_id=event_data.get('element_id'),
                x=event_data.get('x'),
                y=event_data.get('y'),
                viewport_width=event_data.get('viewport_width'),
                viewport_height=event_data.get('viewport_height'),
                timestamp=event_data.get('timestamp')
            )
            events.append(event)

        # Save events
        store.save_events_batch(events)
        current_app.logger.debug(f"[User: {username}] Saved {len(events)} analytics events")

        return jsonify({'success': True, 'count': len(events)})

    except Exception as e:
        current_app.logger.error(f"Error tracking analytics: {e}")
        current_app.logger.error(traceback.format_exc())
        return jsonify({'success': False, 'error': str(e)}), 500
