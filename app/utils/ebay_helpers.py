"""Helper functions for eBay-specific operations."""
import re


def extract_ebay_description_section(full_description):
    """
    Extract the user-editable description section from a full eBay item description.

    The full description may contain:
    - User's description (editable)
    - Boilerplate sections (policies, etc.)

    This function extracts only the editable portion.

    Args:
        full_description (str): Full HTML description from eBay

    Returns:
        str: Extracted description section or original if no markers found
    """
    if not full_description:
        return ''

    # Try to find content between description markers
    pattern = r'<!--DESCRIPTION_START-->(.*?)<!--DESCRIPTION_END-->'
    match = re.search(pattern, full_description, re.DOTALL)

    if match:
        return match.group(1).strip()

    # Fallback: return full description
    return full_description


def extract_ebay_condition_section(full_description):
    """
    Extract the condition description section from a full eBay item description.

    Args:
        full_description (str): Full HTML description from eBay

    Returns:
        str: Extracted condition section or empty string
    """
    if not full_description:
        return ''

    # Try to find content between condition markers
    pattern = r'<!--CONDITION_START-->(.*?)<!--CONDITION_END-->'
    match = re.search(pattern, full_description, re.DOTALL)

    if match:
        return match.group(1).strip()

    return ''


def resolve_ebay_context(payload):
    """
    Extract eBay listing parameters from an API request payload.

    Parses environment, listing mode, field overrides, and schedule time
    from the JSON body sent by the frontend.

    Args:
        payload (dict): JSON body from the API request. Expected keys:
            - environment (str): 'production' or 'sandbox' (default: 'production')
            - mode (str): Listing mode — 'list', 'update', 'schedule', etc. (default: 'list')
            - overrides (dict): Optional field overrides for the Trading API item
            - schedule_time (str): Optional ISO-8601 datetime for scheduled listings

    Returns:
        tuple: (environment, listing_mode, overrides, schedule_time)
    """
    if not payload:
        payload = {}

    environment = payload.get('environment', 'production')
    listing_mode = payload.get('mode', 'list')
    overrides = payload.get('overrides') or {}
    schedule_time = payload.get('schedule_time') or None

    return environment, listing_mode, overrides, schedule_time


def validate_ebay_item_id(item_id):
    """
    Validate an eBay item ID format.

    eBay item IDs are typically numeric strings of 12-14 digits.

    Args:
        item_id (str): Item ID to validate

    Returns:
        tuple: (bool, str) - (is_valid, error_message)
            - is_valid: True if valid, False otherwise
            - error_message: Detailed error message if invalid, empty string if valid
    """
    if not item_id:
        return False, "eBay Item ID is required"

    # Remove any whitespace
    item_id = str(item_id).strip()

    # Check if it's numeric and reasonable length
    if not item_id.isdigit():
        return False, "eBay Item ID must be numeric"

    # eBay item IDs are typically 12-14 digits
    if len(item_id) < 10 or len(item_id) > 15:
        return False, f"eBay Item ID must be 10-15 digits (got {len(item_id)})"

    return True, ""

    return True, ""


def get_ebay_validation_data():
    """
    Get eBay field validation data for frontend.

    This provides the frontend with information about:
    - Required fields
    - Field types
    - Allowed values
    - Validation rules

    Returns:
        dict: eBay validation configuration
    """
    from app.utils.ebay_validators import EBAY_FIELD_VALIDATION
    return EBAY_FIELD_VALIDATION
