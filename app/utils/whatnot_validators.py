"""Whatnot data validation utilities."""

from typing import Any

# ============================================================================
# METADATA FIELD NAMES (stored in CSV but not exported)
# ============================================================================
METADATA_FIELD_NAMES = {
    'SKU': 'SKU',
    'ADDED_BY': 'Added By',
    'DATE_ADDED': 'Date Added',
    'LAST_MODIFIED': 'Last Modified',
    'EBAY_ITEM_ID': 'eBay Item ID',
    'WHATNOT_ITEM_ID': 'WhatNot Item ID',
    'EBAY_ALLOW_OFFERS': 'eBay Allow Offers',
    'EBAY_OFFER_MIN': 'eBay Offer Min',
    'EBAY_OFFER_MAX': 'eBay Offer Max'
}

# List of metadata fields (for backward compatibility)
METADATA_FIELDS = list(METADATA_FIELD_NAMES.values())

# ============================================================================
# WHATNOT FIELD NAMES - Change these to rename columns in CSV/exports
# ============================================================================
WHATNOT_FIELD_NAMES = {
    'CATEGORY': 'Category',
    'SUB_CATEGORY': 'Sub Category',
    'TITLE': 'Title',
    'DESCRIPTION': 'Description',
    'QUANTITY': 'Quantity',
    'TYPE': 'Type',
    'PRICE': 'Price',
    'SHIPPING_PROFILE': 'Shipping Profile',
    'OFFERABLE': 'Offerable',
    'HAZMAT': 'Hazmat',
    'CONDITION': 'Condition',
    'CONDITION_DETAILS': 'Condition Details',
    'PHOTOS_DETAILS': 'Photos Details',
    'SHIPPING_DETAILS': 'Shipping Details',
    'SIGNOFF': 'Signoff',
    'COST_PER_ITEM': 'Cost Per Item',
    'LISTING_TYPE': 'Listing Type',
    'SKU': 'SKU',
    'IMAGE_URL_1': 'Image URL 1',
    'IMAGE_URL_2': 'Image URL 2',
    'IMAGE_URL_3': 'Image URL 3',
    'IMAGE_URL_4': 'Image URL 4',
    'IMAGE_URL_5': 'Image URL 5',
    'IMAGE_URL_6': 'Image URL 6',
    'IMAGE_URL_7': 'Image URL 7',
    'IMAGE_URL_8': 'Image URL 8'
}

# Field mapping from internal item data to Whatnot fields
WHATNOT_FIELD_MAPPING = {
    WHATNOT_FIELD_NAMES['SKU']: 'sku',
    WHATNOT_FIELD_NAMES['TITLE']: 'title',
    WHATNOT_FIELD_NAMES['DESCRIPTION']: 'description',
    WHATNOT_FIELD_NAMES['PRICE']: 'price',
    WHATNOT_FIELD_NAMES['QUANTITY']: 'quantity',
    WHATNOT_FIELD_NAMES['CONDITION']: 'condition',
    WHATNOT_FIELD_NAMES['IMAGE_URL_1']: 'image_urls',  # First image
}

# ============================================================================
# WHATNOT FIELD VALIDATION - Uses WHATNOT_FIELD_NAMES for column references
# ============================================================================
WHATNOT_FIELD_VALIDATION = {
    WHATNOT_FIELD_NAMES['CATEGORY']: {
        'required': True,
        'allowed_values': ['Comics & Manga'],
        'default': 'Comics & Manga'
    },
    WHATNOT_FIELD_NAMES['SUB_CATEGORY']: {
        'required': True,
        'allowed_values': [
            'Anime & Manga',
            'Comic Art',
            'Modern Comics',
            'Pop Culture Memorabilia',
            'Vintage Comics'
        ],
        'default': 'Modern Comics'
    },
    WHATNOT_FIELD_NAMES['TITLE']: {
        'required': True,
        'not_blank': True,
        'auto_populate': True,
        'source_field': 'title'
    },
    WHATNOT_FIELD_NAMES['DESCRIPTION']: {
        'required': True,
        'not_blank': True,
        'auto_populate': True,
        'source_field': 'description'
    },
    WHATNOT_FIELD_NAMES['QUANTITY']: {
        'required': True,
        'type': 'integer',
        'default': '1',
        'auto_populate': True,
        'source_field': 'quantity'
    },
    WHATNOT_FIELD_NAMES['TYPE']: {
        'required': True,
        'allowed_values': ['Buy it Now', 'Auction', 'Giveaway'],
        'default': 'Buy it Now'
    },
    WHATNOT_FIELD_NAMES['PRICE']: {
        'required': True,
        'type': 'currency',
        'auto_populate': True,
        'source_field': 'price'
    },
    WHATNOT_FIELD_NAMES['SHIPPING_PROFILE']: {
        'required': True,
        'allowed_values': [
            'One Comic (Gemeni Mailer)',
            'Multi (Gemeni Mailer)',
            'Dynamic (Gemeni Mailer)',
            'Flate Rate Box o Comics',
            'Comic Slab (USPS Medium Box)',
            '0-1 oz',
            '1-3 oz',
            '4-7 oz',
            '8-11 oz',
            '12-15 oz',
            '1 lb'
        ],
        'default': 'Dynamic (Gemeni Mailer)'
    },
    WHATNOT_FIELD_NAMES['OFFERABLE']: {
        'required': True,
        'allowed_values': ['TRUE', 'FALSE'],
        'default': 'TRUE'
    },
    WHATNOT_FIELD_NAMES['HAZMAT']: {
        'required': True,
        'allowed_values': ['Not Hazmat'],
        'default': 'Not Hazmat'
    },
    WHATNOT_FIELD_NAMES['CONDITION']: {
        'required': True,
        'allowed_values': [
            'Graded',
            'Gem Mint',
            'Mint',
            'Near Mint',
            'Very Fine',
            'Fine',
            'Very Good',
            'Good',
            'Fair',
            'Poor'
        ],
        'default': 'Near Mint',
        'auto_populate': True,
        'source_field': 'condition'
    },
    WHATNOT_FIELD_NAMES['CONDITION_DETAILS']: {
        'required': False,
        'type': 'string',
        'default': '',
        'auto_populate': True,
        'source_field': 'condition_details'
    },
    WHATNOT_FIELD_NAMES['PHOTOS_DETAILS']: {
        'required': False,
        'type': 'string',
        'default': 'Exact book is pictured\nScans and stand up pictures',
        'auto_populate': True,
        'source_field': 'photos_details'
    },
    WHATNOT_FIELD_NAMES['SHIPPING_DETAILS']: {
        'required': False,
        'type': 'string',
        'default': 'All comics are bagged and boarded\nSecurely ships in Gemini Mailer within two business days',
        'auto_populate': True,
        'source_field': 'shipping_details'
    },
    WHATNOT_FIELD_NAMES['SIGNOFF']: {
        'required': False,
        'type': 'string',
        'default': 'Thanks for looking, Message with any questions',
        'auto_populate': True,
        'source_field': 'signoff'
    },
    WHATNOT_FIELD_NAMES['COST_PER_ITEM']: {
        'required': False,
        'type': 'integer',
        'default': '0'
    },
    WHATNOT_FIELD_NAMES['LISTING_TYPE']: {
        'required': False,
        'allowed_values': ['For Sale', 'Giveaway'],
        'default': 'For Sale'
    },
    WHATNOT_FIELD_NAMES['SKU']: {
        'required': True,
        'not_blank': True,
        'type': 'integer',
        'auto_populate': True,
        'source_field': 'sku'
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_1']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 0
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_2']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 1
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_3']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 2
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_4']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 3
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_5']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 4
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_6']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 5
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_7']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 6
    },
    WHATNOT_FIELD_NAMES['IMAGE_URL_8']: {
        'required': False,
        'auto_populate': True,
        'source_field': 'image_urls',
        'is_list': True,
        'list_index': 7
    }
}


def validate_whatnot_data(data):
    """
    Validate data against Whatnot field rules.
    
    Args:
        data: Dictionary containing data with field names as keys
    
    Returns:
        tuple: (is_valid, list of error messages)
    """
    errors = []
    
    for field_name, rules in WHATNOT_FIELD_VALIDATION.items():
        value = data.get(field_name, '').strip() if isinstance(data.get(field_name), str) else str(data.get(field_name, ''))
        
        # Check if required and no value and no default
        if rules.get('required') and not value:
            if 'default' not in rules:
                errors.append(f"{field_name} is required")
                continue
        
        # Check if not blank
        if rules.get('not_blank') and not value:
            if 'default' not in rules:
                errors.append(f"{field_name} cannot be blank")
                continue
        
        # Check allowed values (only if value is not empty)
        if 'allowed_values' in rules and value:
            if value not in rules['allowed_values']:
                errors.append(f"{field_name} must be one of: {', '.join(rules['allowed_values'])}")
        
        # Check type validations (only if value is not empty)
        if 'type' in rules and value:
            if rules['type'] == 'integer':
                try:
                    int(value)
                except ValueError:
                    errors.append(f"{field_name} must be an integer")
            elif rules['type'] == 'currency':
                try:
                    float(value.replace('$', '').replace(',', ''))
                except ValueError:
                    errors.append(f"{field_name} must be a valid dollar amount")
    
    return len(errors) == 0, errors


def allowed_file(filename, allowed_extensions=None):
    """Check if filename has an allowed extension."""
    if allowed_extensions is None:
        allowed_extensions = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
    if not filename or not isinstance(filename, str):
        return False
    # Reject path separators and NUL bytes outright — these should never
    # appear in a legitimate uploaded filename.
    if '/' in filename or '\\' in filename or '\x00' in filename:
        return False
    if '.' not in filename:
        return False
    return filename.rsplit('.', 1)[1].lower() in allowed_extensions


def populate_whatnot_fields_from_item(item):
    """
    Auto-populate Whatnot fields from item data.

    Args:
        item: Item object or dictionary with item data

    Returns:
        dict: Dictionary with Whatnot field names as keys and populated values
    """
    whatnot_data = {}

    for whatnot_field, rules in WHATNOT_FIELD_VALIDATION.items():
        if rules.get('auto_populate') and rules.get('source_field'):
            source_field = rules['source_field']

            # Get value from item (works for both dict and object)
            if isinstance(item, dict):
                value = item.get(source_field)
            else:
                value = getattr(item, source_field, None)

            if value is not None:
                # Handle special field types
                if rules.get('is_list'):
                    # For image URLs - get specific index from list
                    if isinstance(value, list):
                        list_index = rules.get('list_index', 0)
                        if list_index < len(value):
                            whatnot_data[whatnot_field] = str(value[list_index])
                    elif isinstance(value, str) and value:
                        # If it's a string, assume it's the first image
                        whatnot_data[whatnot_field] = value
                else:
                    # Standard field - just convert to string
                    whatnot_data[whatnot_field] = str(value)

            elif 'default' in rules:
                # Use default if no value provided
                whatnot_data[whatnot_field] = rules['default']

        # Add defaults for non-auto-populated required fields
        elif 'default' in rules and whatnot_field not in whatnot_data:
            whatnot_data[whatnot_field] = rules['default']

    return whatnot_data


def is_whatnot_listed(item: Any) -> bool:
    """Return True when an item is tagged as listed on WhatNot.

    The canonical stored flag is the metadata field ``WhatNot Item ID`` with
    string value ``'TRUE'``. Some call sites work with raw dictionaries while
    others work with ``Comic`` objects, so this helper normalizes both.
    """
    raw_value = ''

    if isinstance(item, dict):
        raw_value = (
            item.get(METADATA_FIELD_NAMES['WHATNOT_ITEM_ID'])
            or item.get('whatnot_item_id')
            or ''
        )
    else:
        raw_value = getattr(item, 'whatnot_item_id', '') or ''

    return str(raw_value).strip().upper() == 'TRUE'


def get_whatnot_export_fieldnames() -> list[str]:
    """Return the canonical WhatNot CSV column order."""
    return list(WHATNOT_FIELD_VALIDATION.keys())


def build_whatnot_export_row(item: Any) -> dict[str, str]:
    """Build one full-schema WhatNot export row for ``item``.

    This matches the existing proper WhatNot export format used by the main
    download flow: auto-populated values, validator defaults, and all columns
    present in the exact validator-defined order.
    """
    whatnot_data = populate_whatnot_fields_from_item(item)
    fieldnames = get_whatnot_export_fieldnames()

    for field, rules in WHATNOT_FIELD_VALIDATION.items():
        if field not in whatnot_data and 'default' in rules:
            whatnot_data[field] = rules['default']

    for field in fieldnames:
        if field not in whatnot_data:
            whatnot_data[field] = ''

    return {field: whatnot_data[field] for field in fieldnames}


def get_whatnot_auto_populate_fields():
    """
    Get list of Whatnot fields that can be auto-populated from item data.

    Returns:
        list: List of tuples (whatnot_field_name, source_field_name, is_list, list_index)
    """
    auto_fields = []
    for whatnot_field, rules in WHATNOT_FIELD_VALIDATION.items():
        if rules.get('auto_populate'):
            source_field = rules.get('source_field', '')
            is_list = rules.get('is_list', False)
            list_index = rules.get('list_index', None)
            auto_fields.append((whatnot_field, source_field, is_list, list_index))
    return auto_fields
