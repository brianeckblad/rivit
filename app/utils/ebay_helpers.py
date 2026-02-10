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


def resolve_ebay_context(comic_data):
    """
    Determine the eBay listing context from comic data.

    Returns one of:
    - 'new_listing': Comic has never been listed on eBay
    - 'listed': Comic is currently listed on eBay
    - 'ended': Comic was listed but listing has ended

    Args:
        comic_data (dict): Comic data dictionary

    Returns:
        str: Context identifier
    """
    ebay_item_id = comic_data.get('eBay Item ID', '')
    listing_type = comic_data.get('Listing Type', '')

    if not ebay_item_id:
        return 'new_listing'

    if listing_type == 'For Sale eBay':
        return 'listed'

    return 'ended'


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
