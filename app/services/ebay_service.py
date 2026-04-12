"""eBay Finding API and Browse API service for price lookups."""
import os
import json
import re
import time
import base64
import hashlib
import requests
from datetime import datetime
from difflib import SequenceMatcher
from flask import current_app
from app.utils.ebay_validators import build_trading_item
from ebaysdk.trading import Connection as Trading
from ebaysdk.exception import ConnectionError as TradingError


class EbayDuplicateListingError(Exception):
    """
    Exception raised when eBay detects a duplicate listing.

    Attributes:
        message: Error message from eBay
        existing_item_id: eBay item ID of the existing duplicate listing
        existing_title: Title of the existing listing (if available)
    """
    def __init__(self, message, existing_item_id=None, existing_title=None):
        self.message = message
        self.existing_item_id = existing_item_id
        self.existing_title = existing_title
        super().__init__(self.message)

    def __str__(self):
        if self.existing_item_id and self.existing_title:
            return (f"This item appears to be a duplicate of an existing eBay listing.\n"
                   f"Existing listing: {self.existing_title} (Item ID: {self.existing_item_id})\n"
                   f"Please check your eBay listings or increase the quantity of the existing item.")
        elif self.existing_item_id:
            return (f"This item appears to be a duplicate of an existing eBay listing (Item ID: {self.existing_item_id}).\n"
                   f"Please check your eBay listings or increase the quantity of the existing item.")
        else:
            return f"Duplicate listing detected: {self.message}"


class EbayService:
    """
    Service for interacting with eBay's Finding and Browse APIs.
    
    This service provides methods for searching completed listings (for pricing),
    active listings, and searching by image (visual search). It handles OAuth
    authentication, rate limit tracking, and caching of results.
    """

    # Production URLs
    FINDING_API_URL_PROD = "https://svcs.ebay.com/services/search/FindingService/v1"
    BROWSE_API_URL_PROD = "https://api.ebay.com/buy/browse/v1"
    OAUTH_URL_PROD = "https://api.ebay.com/identity/v1/oauth2/token"

    # Sandbox URLs
    FINDING_API_URL_SANDBOX = "https://svcs.sandbox.ebay.com/services/search/FindingService/v1"
    BROWSE_API_URL_SANDBOX = "https://api.sandbox.ebay.com/buy/browse/v1"
    OAUTH_URL_SANDBOX = "https://api.sandbox.ebay.com/identity/v1/oauth2/token"

    def __init__(self):
        """Initialize the eBay service and determine the environment (production/sandbox)."""
        # User-specific state (cached per user to avoid repeated AWS calls)
        self._user_credentials_cache = {}  # {username: {credentials}}
        self._user_tokens_cache = {}  # {username: {'token': ..., 'expires': ...}}

        # Shared cache for search results (include username in cache keys)
        self.cache = {}  # Simple in-memory cache
        self.cache_ttl = 3600  # Default TTL
        self._logged_init = False  # Track if we've logged initialization

        # API call tracking for monitoring (shared across all users)
        self._call_counts = {}  # Track API calls by type

        # Category tree cache (shared across all users - categories are the same)
        instance_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), '..', 'instance')
        os.makedirs(instance_dir, exist_ok=True)  # Ensure instance directory exists
        self.category_cache_file = os.path.join(instance_dir, 'ebay_category_cache.json')
        self.category_tree_cache = None  # Full category tree cache
        self.category_tree_version = None  # Track eBay's category tree version

        # Determine environment (default to production)
        self.environment = os.getenv('EBAY_ENVIRONMENT', 'production').lower()

        # Set API URLs based on environment
        if self.environment == 'sandbox':
            self.finding_api_url = self.FINDING_API_URL_SANDBOX
            self.browse_api_url = self.BROWSE_API_URL_SANDBOX
            self.oauth_url = self.OAUTH_URL_SANDBOX
        else:
            self.finding_api_url = self.FINDING_API_URL_PROD
            self.browse_api_url = self.BROWSE_API_URL_PROD
            self.oauth_url = self.OAUTH_URL_PROD

    def _log_init(self):
        """
        Log initialization details. 
        
        Called lazily to ensure the Flask application context is available 
        for logging.
        """
        if not self._logged_init:
            try:
                # Update TTL from config if available
                self.cache_ttl = current_app.config.get('EBAY_CACHE_TTL', 3600)
                
                mode = "SANDBOX" if self.environment == 'sandbox' else "PRODUCTION"
                current_app.logger.info(f"eBay Service initialized in {mode} mode")
                self._logged_init = True
            except RuntimeError:
                # App context not available yet, skip logging
                pass

    def initialize_category_cache(self, marketplace_id='EBAY_US'):
        """
        Initialize category cache on app startup.

        This method:
        1. Ensures instance directory exists
        2. Loads existing cache if available
        3. If cache doesn't exist or is invalid, fetches from eBay
        4. Creates empty cache as fallback if eBay fetch fails

        Args:
            marketplace_id: The marketplace ID (e.g., 'EBAY_US')
        """
        try:
            # Ensure instance directory exists
            cache_dir = os.path.dirname(self.category_cache_file)
            os.makedirs(cache_dir, exist_ok=True)

            current_app.logger.info(f"Initializing category cache (file: {self.category_cache_file})")

            # Try to load existing cache
            if self._load_category_cache():
                file_size = os.path.getsize(self.category_cache_file)
                current_app.logger.info(f"✓ Category cache loaded from file ({file_size} bytes)")
                return True

            # No cache exists - try to fetch it
            current_app.logger.info("⚠ No category cache found - fetching from eBay (this will take 5-10 seconds)...")
            result = self._fetch_full_category_tree(marketplace_id)

            if 'error' not in result:
                # Verify file was actually created
                if os.path.exists(self.category_cache_file):
                    file_size = os.path.getsize(self.category_cache_file)
                    current_app.logger.info(f"✓ Category cache initialized successfully ({file_size} bytes saved)")
                    return True
                else:
                    current_app.logger.error(f"⚠ Cache was fetched but file was not created: {self.category_cache_file}")
            else:
                error_msg = result.get('error')
                current_app.logger.warning(f"Failed to fetch category cache from eBay: {error_msg}")

            # If we got here, either eBay fetch failed or file wasn't created
            current_app.logger.info("Creating empty cache file as fallback...")
            return self._create_empty_cache()

        except Exception as e:
            current_app.logger.error(f"Error initializing category cache: {e}")
            import traceback
            current_app.logger.error(traceback.format_exc())
            # Create empty cache as last resort
            try:
                return self._create_empty_cache()
            except Exception as e2:
                current_app.logger.error(f"Failed to create empty cache: {e2}")
                return False

    def _create_empty_cache(self):
        """Create an empty but valid cache file."""
        try:
            empty_cache = {
                'tree': {
                    'categoryTreeId': '0',
                    'categoryTreeVersion': 'empty',
                    'categoryTreeNode': {
                        'categoryId': '0',
                        'categoryName': 'All Categories',
                        'childCategoryTreeNodes': []
                    }
                },
                'version': 'empty',
                'cached_at': datetime.now().isoformat()
            }

            # Ensure directory exists
            cache_dir = os.path.dirname(self.category_cache_file)
            if cache_dir:
                os.makedirs(cache_dir, exist_ok=True)

            # Write empty cache
            with open(self.category_cache_file, 'w') as f:
                json.dump(empty_cache, f, indent=2)

            self.category_tree_cache = empty_cache['tree']
            self.category_tree_version = 'empty'
            current_app.logger.info(f"Created empty cache file: {self.category_cache_file}")
            return True
        except Exception as e:
            current_app.logger.error(f"Failed to create empty cache: {e}")
            return False


    def _get_app_id(self, username=None):
        """Get eBay App ID from config based on environment and current user."""
        from app.utils.user_context import get_current_username, get_ebay_credentials

        if username is None:
            username = get_current_username()

        # Check if we have cached credentials for this user
        if username not in self._user_credentials_cache:
            self._user_credentials_cache[username] = get_ebay_credentials(username)

        creds = self._user_credentials_cache[username]

        if self.environment == 'sandbox':
            return creds.get('EBAY_SANDBOX_APP_ID') or os.getenv('EBAY_SANDBOX_APP_ID') or current_app.config.get('EBAY_SANDBOX_APP_ID')
        else:
            return creds.get('EBAY_PRODUCTION_APP_ID') or os.getenv('EBAY_PRODUCTION_APP_ID') or current_app.config.get('EBAY_PRODUCTION_APP_ID')

    def _get_cert_id(self, username=None):
        """Get eBay Cert ID (Client Secret) from config based on environment and current user."""
        from app.utils.user_context import get_current_username, get_ebay_credentials

        if username is None:
            username = get_current_username()

        # Check if we have cached credentials for this user
        if username not in self._user_credentials_cache:
            self._user_credentials_cache[username] = get_ebay_credentials(username)

        creds = self._user_credentials_cache[username]

        if self.environment == 'sandbox':
            return creds.get('EBAY_SANDBOX_CERT_ID') or os.getenv('EBAY_SANDBOX_CERT_ID') or current_app.config.get('EBAY_SANDBOX_CERT_ID')
        else:
            return creds.get('EBAY_PRODUCTION_CERT_ID') or os.getenv('EBAY_PRODUCTION_CERT_ID') or current_app.config.get('EBAY_PRODUCTION_CERT_ID')

    def _get_oauth_token(self, username=None):
        """Get OAuth 2.0 access token for the current user, refreshing if needed."""
        from app.utils.user_context import get_current_username

        if username is None:
            username = get_current_username()

        # Check if current token for this user is still valid
        if username in self._user_tokens_cache:
            token_data = self._user_tokens_cache[username]
            if token_data['token'] and time.time() < token_data['expires']:
                return token_data['token']

        app_id = self._get_app_id(username)
        cert_id = self._get_cert_id(username)

        if not app_id or not cert_id:
            # Provide detailed error message about which credentials are missing
            missing_creds = []
            if not app_id:
                if self.environment == 'sandbox':
                    missing_creds.append('EBAY_SANDBOX_APP_ID')
                else:
                    missing_creds.append('EBAY_PRODUCTION_APP_ID')
            if not cert_id:
                if self.environment == 'sandbox':
                    missing_creds.append('EBAY_SANDBOX_CERT_ID')
                else:
                    missing_creds.append('EBAY_PRODUCTION_CERT_ID')

            current_app.logger.error(f"[User: {username}] Missing eBay credentials for {self.environment}: {', '.join(missing_creds)}")
            return None

        current_app.logger.info(f"[User: {username}] Requesting OAuth token for {self.environment} environment")

        try:
            # Create Basic Auth credentials
            credentials = f"{app_id}:{cert_id}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()

            # Request OAuth token using Client Credentials grant
            headers = {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': f'Basic {encoded_credentials}'
            }

            data = {
                'grant_type': 'client_credentials',
                'scope': 'https://api.ebay.com/oauth/api_scope'
            }

            response = requests.post(self.oauth_url, headers=headers, data=data, timeout=10)

            if response.status_code != 200:
                current_app.logger.error(f"[User: {username}] OAuth token request failed: {response.status_code} - {response.text}")
                return None

            token_data = response.json()
            oauth_token = token_data.get('access_token')
            expires_in = token_data.get('expires_in', 7200)  # Default 2 hours
            token_expires = time.time() + expires_in - 60  # Refresh 1 min early

            # Cache token for this user
            self._user_tokens_cache[username] = {
                'token': oauth_token,
                'expires': token_expires
            }

            current_app.logger.info(f"[User: {username}] Successfully obtained eBay OAuth token")
            return oauth_token

        except Exception as e:
            current_app.logger.error(f"[User: {username}] Error getting OAuth token: {e}")
            return None

    def _get_cache_key(self, title, condition, limit, username=None):
        """Generate cache key from search parameters, including username for multi-user isolation."""
        from app.utils.user_context import get_current_username

        if username is None:
            username = get_current_username()

        key_str = f"{username}:{title}:{condition}:{limit}"
        return hashlib.md5(key_str.encode()).hexdigest()

    def _set_cache(self, cache_key, result):
        """Store result in cache."""
        self.cache[cache_key] = (result, time.time())
        
        # Also save to disk for sharing between workers
        try:
            cache_dir = os.path.join(current_app.instance_path, 'ebay_cache')
            os.makedirs(cache_dir, exist_ok=True)
            cache_file = os.path.join(cache_dir, f"{cache_key}.json")
            with open(cache_file, 'w') as f:
                json.dump({
                    'result': result,
                    'timestamp': time.time()
                }, f)
        except Exception as e:
            current_app.logger.warning(f"Error saving eBay cache to disk: {e}")

    def _get_cached_result(self, cache_key):
        """Get cached result if still valid."""
        # Try memory cache first
        if cache_key in self.cache:
            result, timestamp = self.cache[cache_key]
            if time.time() - timestamp < self.cache_ttl:
                return result
            else:
                del self.cache[cache_key]

        # Try disk cache
        try:
            cache_file = os.path.join(current_app.instance_path, 'ebay_cache', f"{cache_key}.json")
            if os.path.exists(cache_file):
                with open(cache_file, 'r') as f:
                    data = json.load(f)
                    result = data['result']
                    timestamp = data['timestamp']
                    if time.time() - timestamp < self.cache_ttl:
                        # Update memory cache
                        self.cache[cache_key] = (result, timestamp)
                        return result
                    else:
                        os.remove(cache_file)
        except Exception as e:
            current_app.logger.warning(f"Error reading eBay cache from disk: {e}")
            
        return None

    def search_completed_items(self, title, condition=None, limit=10):
        """
        Search for completed and sold listings on eBay to assist with pricing.
        
        This method uses the 'findItemsAdvanced' operation of the Finding API. 
        It filters for sold items only, restricted to the 'Comic Books' category.
        
        Args:
            title (str): The comic title to search for.
            condition (str, optional): The condition filter. Defaults to None.
            limit (int): Maximum number of results to return. Defaults to 10.
            
        Returns:
            dict: Parsed search results including item titles, prices, and URLs.
        """
        self._log_init()  # Log initialization on first use

        try:
            # Check cache first
            cache_key = self._get_cache_key(title, condition, limit)
            cached = self._get_cached_result(cache_key)
            if cached:
                cached['cached'] = True
                return cached

            app_id = self._get_app_id()
            if not app_id:
                return {'success': False, 'error': 'eBay App ID not configured'}

            # Build search keywords - add "comic" to improve relevance
            search_keywords = f"{title} comic"

            # Build request parameters
            # Note: Using findItemsAdvanced instead of findCompletedItems
            # findCompletedItems has very restrictive rate limits
            params = {
                'OPERATION-NAME': 'findItemsAdvanced',
                'SERVICE-VERSION': '1.0.0',
                'SECURITY-APPNAME': app_id,
                'RESPONSE-DATA-FORMAT': 'JSON',
                'keywords': search_keywords,
                'paginationInput.entriesPerPage': str(limit),  # Use configurable limit
                'categoryId': '63',  # Comic Books category
                'itemFilter(0).name': 'SoldItemsOnly',
                'itemFilter(0).value': 'true',
                'itemFilter(1).name': 'ListingType',
                'itemFilter(1).value': 'FixedPrice'  # Buy It Now only (no auctions)
            }

            # Map common condition strings to eBay Condition IDs
            condition_map = {
                'new': '1000',
                'used': '3000',
                'like new': '1500',
                'very good': '2000',
                'good': '2500',
                'acceptable': '4000'
            }

            # Add condition filter if specified, default to Used (3000) for comics if not specified
            ebay_condition = '3000'
            if condition:
                cond_lower = condition.lower()
                if cond_lower in condition_map:
                    ebay_condition = condition_map[cond_lower]
                elif condition.isdigit():
                    ebay_condition = condition
            
            params['itemFilter(2).name'] = 'Condition'
            params['itemFilter(2).value'] = ebay_condition

            # Make API request
            current_app.logger.info(f"eBay Finding API request ({self.environment}): {search_keywords}")
            response = requests.get(self.finding_api_url, params=params, timeout=10)


            # Log rate limit headers if available
            rl_limit = response.headers.get('X-EBAY-API-CALL-LIMIT')
            rl_remaining = response.headers.get('X-EBAY-API-CALL-LIMIT-REMAINING')
            if rl_limit or rl_remaining:
                current_app.logger.info(f"eBay Finding API Rate Limit: {rl_remaining}/{rl_limit}")

            # Check response status
            if response.status_code != 200:
                current_app.logger.error(f"eBay Finding API HTTP error: {response.status_code} - {response.text}")

                # Try to parse error details from response
                try:
                    error_data = response.json()
                    error_msg = error_data.get('errorMessage', [{}])[0]
                    error_detail = error_msg.get('error', [{}])[0]
                    error_id = error_detail.get('errorId', ['Unknown'])[0]
                    error_message = error_detail.get('message', ['Unknown error'])[0]

                    # Specific handling for rate limit errors
                    if error_id == '10001' or 'limit' in error_message.lower() or 'quota' in error_message.lower():
                        return {
                            'success': False,
                            'error': 'The eBay service for looking up sold prices is currently unavailable due to daily API limits. However, you can still use the image search results (which show current prices) as a guide.',
                            'rate_limit': True,
                            'api_type': 'FindingAPI'
                        }

                    return {'success': False, 'error': f'eBay API error {error_id}: {error_message}'}
                except Exception:
                    return {'success': False, 'error': f'eBay Finding API returned HTTP {response.status_code}'}

            data = response.json()

            # Parse response (using findItemsAdvanced response format)
            search_result = data.get('findItemsAdvancedResponse', [{}])[0]
            ack = search_result.get('ack', [None])[0]

            if ack != 'Success':
                error_msg = search_result.get('errorMessage', [{}])[0]
                error_detail = error_msg.get('error', [{}])[0]
                error_id = error_detail.get('errorId', ['Unknown'])[0]
                error_message = error_detail.get('message', ['Unknown error'])[0]

                current_app.logger.error(f"eBay API error {error_id}: {error_message}")

                # Specific handling for rate limit errors
                if error_id == '10001' or 'limit' in error_message.lower() or 'quota' in error_message.lower():
                    return {
                        'success': False,
                        'error': 'The eBay service for looking up sold prices is currently unavailable due to daily API limits. However, you can still use the image search results (which show current prices) as a guide.',
                        'rate_limit': True,
                        'api_type': 'FindingAPI'
                    }

                return {
                    'success': False,
                    'error': f'{error_message}',
                    'api_type': 'FindingAPI'
                }

            # Extract items
            search_items = search_result.get('searchResult', [{}])[0]
            items = search_items.get('item', [])

            # Specific handling for "Call Usage Limit Reached" error
            if ack == 'Failure' or ack == 'PartialFailure':
                error_msg = search_result.get('errorMessage', [{}])[0]
                error_detail = error_msg.get('error', [{}])[0]
                error_id = error_detail.get('errorId', ['Unknown'])[0]
                error_message = error_detail.get('message', ['Unknown error'])[0]
                
                if 'limit' in error_message.lower() or 'quota' in error_message.lower() or error_id == '10001':
                    return {
                        'success': False,
                        'error': 'The eBay service for looking up sold prices is currently unavailable due to daily API limits. However, you can still use the image search results (which show current prices) as a guide.',
                        'rate_limit': True,
                        'api_type': 'FindingAPI'
                    }

            # Also check if paginationOutput says 0
            pagination = search_result.get('paginationOutput', [{}])[0]
            total_entries = pagination.get('totalEntries', ['0'])[0]
            if int(total_entries) == 0 and not items:
                current_app.logger.info(f"eBay returned 0 results for: {search_keywords}")

            # Format results (use the requested limit)
            results = []
            for item in items[:limit]:  # Process up to the requested limit
                try:
                    sold_price = item.get('sellingStatus', [{}])[0].get('currentPrice', [{}])[0].get('__value__', '0')
                    condition_name = item.get('condition', [{}])[0].get('conditionDisplayName', ['Unknown'])[0]

                    results.append({
                        'title': item.get('title', ['No title'])[0],
                        'itemId': item.get('itemId', [''])[0],
                        'price': float(sold_price),
                        'condition': condition_name,
                        'listing_url': item.get('viewItemURL', [''])[0],
                        'image_url': item.get('galleryURL', [''])[0],
                        'end_time': item.get('listingInfo', [{}])[0].get('endTime', [''])[0]
                    })
                except (KeyError, IndexError, ValueError) as e:
                    current_app.logger.warning(f"Error parsing eBay item: {e}")
                    continue

            # Calculate price statistics from all results
            prices = [item['price'] for item in results if item['price'] > 0]
            price_stats = {}

            if prices:
                sorted_prices = sorted(prices)
                median = sorted_prices[len(sorted_prices) // 2] if len(sorted_prices) % 2 != 0 else (sorted_prices[len(sorted_prices) // 2 - 1] + sorted_prices[len(sorted_prices) // 2]) / 2

                price_stats = {
                    'average': round(sum(prices) / len(prices), 2),
                    'median': round(median, 2),
                    'min': round(min(prices), 2),
                    'max': round(max(prices), 2),
                    'total_items': len(prices)
                }

            result = {
                'success': True,
                'count': len(results),
                'items': results,
                'price_stats': price_stats,
                'cached': False
            }

            # Cache successful results
            self._set_cache(cache_key, result)

            return result

        except requests.RequestException as e:
            current_app.logger.error(f"eBay API request error: {e}")
            return {'success': False, 'error': f'API request failed: {str(e)}'}
        except Exception as e:
            current_app.logger.error(f"eBay service error: {e}")
            return {'success': False, 'error': str(e)}

    def get_sold_prices_url(self, title, condition=None):
        """
        Generate an eBay URL for viewing sold listings.
        This bypasses API limits by providing a direct link to eBay's sold listings page.

        Args:
            title (str): The comic title to search for.
            condition (str, optional): The condition filter.

        Returns:
            dict: Contains the URL and instructions for manual lookup.
        """
        import urllib.parse

        # Build search URL with sold items filter
        base_url = "https://www.ebay.com/sch/i.html"
        search_query = f"{title} comic"

        params = {
            '_nkw': search_query,
            '_sacat': '63',  # Comic Books category
            'LH_Sold': '1',  # Sold listings
            'LH_Complete': '1',  # Completed listings
            'LH_BIN': '1',  # Buy It Now only
            '_sop': '13'  # Sort by recently sold
        }

        url = f"{base_url}?{urllib.parse.urlencode(params)}"

        return {
            'success': True,
            'url': url,
            'message': 'eBay API limits reached. Use this URL to view sold prices manually.'
        }

    def search_active_items(self, title, condition=None, limit=20):
        """
        Search for active (current) listings on eBay.

        Args:
            title (str): The comic title to search for.
            condition (str, optional): The condition filter. Defaults to None.
            limit (int): Maximum number of results to return. Defaults to 20.

        Returns:
            dict: Parsed search results for active listings.
        """
        self._log_init()

        try:
            # Check cache first
            cache_key = self._get_cache_key(f"active_{title}", condition, limit)
            cached = self._get_cached_result(cache_key)
            if cached:
                cached['cached'] = True
                return cached

            app_id = self._get_app_id()
            if not app_id:
                return {'success': False, 'error': 'eBay App ID not configured'}

            # Build search keywords
            search_keywords = f"{title} comic"

            # Build request parameters for active listings
            params = {
                'OPERATION-NAME': 'findItemsAdvanced',
                'SERVICE-VERSION': '1.0.0',
                'SECURITY-APPNAME': app_id,
                'RESPONSE-DATA-FORMAT': 'JSON',
                'keywords': search_keywords,
                'paginationInput.entriesPerPage': str(limit),
                'categoryId': '63',  # Comic Books category
                'itemFilter(0).name': 'ListingType',
                'itemFilter(0).value': 'FixedPrice'  # Buy It Now only
            }

            # Add condition filter if specified
            if condition:
                condition_map = {
                    'new': '1000',
                    'used': '3000',
                    'like new': '1500',
                    'very good': '2000',
                    'good': '2500',
                    'acceptable': '4000'
                }

                ebay_condition = '3000'  # Default to Used
                cond_lower = condition.lower()
                if cond_lower in condition_map:
                    ebay_condition = condition_map[cond_lower]
                elif condition.isdigit():
                    ebay_condition = condition

                params['itemFilter(1).name'] = 'Condition'
                params['itemFilter(1).value'] = ebay_condition

            # Make API request
            current_app.logger.info(f"eBay Finding API request for active items ({self.environment}): {search_keywords}")
            response = requests.get(self.finding_api_url, params=params, timeout=10)


            if response.status_code != 200:
                current_app.logger.error(f"eBay Finding API HTTP error: {response.status_code}")
                current_app.logger.error(f"Response body: {response.text[:500]}")

                # Check if it's a rate limit error
                try:
                    error_data = response.json()
                    error_messages = error_data.get('errorMessage', [{}])
                    if error_messages:
                        error = error_messages[0].get('error', [{}])[0]
                        error_id = error.get('errorId', [''])[0]
                        error_msg = error.get('message', [''])[0]

                        if error_id == '10001' or 'rate' in error_msg.lower():
                            return {
                                'success': False,
                                'error': 'Daily API limit reached for Finding API. Please try the image search instead or wait until tomorrow.',
                                'rate_limit': True
                            }
                except Exception:
                    pass

                return {'success': False, 'error': f'eBay API returned HTTP {response.status_code}'}

            # Parse response
            data = response.json()
            search_response = data.get('findItemsAdvancedResponse', [{}])[0]
            ack = search_response.get('ack', [''])[0]

            if ack == 'Failure':
                error_msg = search_response.get('errorMessage', [{}])[0]
                return {'success': False, 'error': 'eBay API error', 'api_type': 'FindingAPI'}

            # Extract items
            search_result = search_response.get('searchResult', [{}])[0]
            items = search_result.get('item', [])

            # Format results
            results = []
            for item in items[:limit]:
                try:
                    current_price = item.get('sellingStatus', [{}])[0].get('currentPrice', [{}])[0].get('__value__', '0')
                    condition_name = item.get('condition', [{}])[0].get('conditionDisplayName', ['Unknown'])[0]

                    results.append({
                        'title': item.get('title', ['No title'])[0],
                        'itemId': item.get('itemId', [''])[0],
                        'price': float(current_price),
                        'condition': condition_name,
                        'listing_url': item.get('viewItemURL', [''])[0],
                        'image_url': item.get('galleryURL', [''])[0],
                        'listing_type': item.get('listingInfo', [{}])[0].get('listingType', [''])[0]
                    })
                except (KeyError, IndexError, ValueError) as e:
                    current_app.logger.warning(f"Error parsing eBay item: {e}")
                    continue

            # Calculate price statistics
            prices = [item['price'] for item in results if item['price'] > 0]
            price_stats = {}

            if prices:
                sorted_prices = sorted(prices)
                median = sorted_prices[len(sorted_prices) // 2] if len(sorted_prices) % 2 != 0 else (sorted_prices[len(sorted_prices) // 2 - 1] + sorted_prices[len(sorted_prices) // 2]) / 2

                price_stats = {
                    'average': round(sum(prices) / len(prices), 2),
                    'median': round(median, 2),
                    'min': round(min(prices), 2),
                    'max': round(max(prices), 2),
                    'total_items': len(prices)
                }

            result = {
                'success': True,
                'count': len(results),
                'items': results,
                'price_stats': price_stats,
                'cached': False
            }

            # Cache successful results
            self._set_cache(cache_key, result)

            current_app.logger.info(f"Found {len(results)} active items")
            return result

        except requests.RequestException as e:
            current_app.logger.error(f"eBay API request error: {e}")
            return {'success': False, 'error': f'API request failed: {str(e)}'}
        except Exception as e:
            current_app.logger.error(f"eBay service error: {e}")
            return {'success': False, 'error': str(e)}

    def search_by_image(self, image_data, limit=20, sort_by_title=None):
        """
        Perform a visual search on eBay using image data.
        
        This method uses eBay's 'search_by_image' Browse API endpoint. 
        It requires an OAuth user token and base64 encoded image data.
        
        Args:
            image_data (str): Base64 encoded image data.
            limit (int): Maximum number of results to return. Defaults to 20.
            sort_by_title (str, optional): Title to use for similarity sorting.
            
        Returns:
            dict: Parsed search results including matched items.
        """
        self._log_init()  # Log initialization on first use

        try:
            # Get OAuth token
            token = self._get_oauth_token()
            if not token:
                return {'success': False, 'error': 'Failed to obtain OAuth token. Check EBAY_APP_ID and EBAY_CERT_ID configuration.'}

            # Prepare request
            url = f"{self.browse_api_url}/item_summary/search_by_image"
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json',
                'X-EBAY-C-MARKETPLACE-ID': 'EBAY_US'
            }

            payload = {
                'image': image_data,
                'limit': str(limit),
                'category_ids': '259104',  # Comic Books category (can be made configurable)
                'filter': 'buyingOptions:{FIXED_PRICE}'  # Only Buy It Now listings
            }

            current_app.logger.info(f"Searching eBay by image (limit: {limit})")
            response = requests.post(url, headers=headers, json=payload, timeout=15)


            # Log rate limit headers for Browse API
            rl_limit = response.headers.get('X-EBAY-C-CALL-LIMIT-REMAINING') # Browse API uses different headers
            if rl_limit:
                current_app.logger.info(f"eBay Browse API Remaining: {rl_limit}")

            if response.status_code != 200:
                error_detail = response.text
                current_app.logger.error(f"eBay image search HTTP error: {response.status_code} - {error_detail}")
                return {'success': False, 'error': f'eBay API returned HTTP {response.status_code}', 'detail': error_detail}

            data = response.json()

            # Parse response
            item_summaries = data.get('itemSummaries', [])

            if not item_summaries:
                return {
                    'success': True,
                    'count': 0,
                    'items': [],
                    'message': 'No similar items found'
                }

            # Format results
            items = []
            filtered_out_count = 0

            for item in item_summaries:
                try:
                    # Check if item is in Comics category (259104) or any of its sub-categories
                    # Comics category IDs: 259104 (main), 63 (older ID)
                    categories = item.get('categories', [])
                    category_ids = [cat.get('categoryId', '') for cat in categories]

                    # Filter: only include items from Comics categories
                    is_comic = False
                    for cat_id in category_ids:
                        # Check if it's the Comics category or starts with 259104 (sub-categories)
                        if cat_id == '259104' or cat_id == '63' or (cat_id and cat_id.startswith('259104')):
                            is_comic = True
                            break

                    if not is_comic:
                        filtered_out_count += 1
                        continue

                    # Get price info
                    price_info = item.get('price', {})
                    price_value = price_info.get('value', '0')

                    # Get image
                    image_obj = item.get('image', {})
                    image_url = image_obj.get('imageUrl', '')

                    item_data = {
                        'title': item.get('title', 'No title'),
                        'itemId': item.get('itemId', ''),
                        'price': float(price_value),
                        'condition': item.get('condition', 'Unknown'),
                        'listing_url': item.get('itemWebUrl', ''),
                        'image_url': image_url,
                        'item_location': item.get('itemLocation', {}).get('country', 'US'),
                        'categories': category_ids
                    }

                    items.append(item_data)

                except (KeyError, ValueError) as e:
                    current_app.logger.warning(f"Error parsing eBay item: {e}")
                    continue

            if filtered_out_count > 0:
                current_app.logger.info(f"Filtered out {filtered_out_count} non-comic items from image search")

            result = {
                'success': True,
                'count': len(items),
                'items': items,
                'environment': self.environment
            }

            # Sort by title similarity if requested
            if sort_by_title and items:
                def similarity_score(item_title, query_title):
                    """Calculate similarity between titles (0-1, higher is more similar)."""
                    return SequenceMatcher(None, item_title.lower(), query_title.lower()).ratio()

                # Score and sort by title similarity
                scored_items = []
                for item in items:
                    score = similarity_score(item['title'], sort_by_title)
                    scored_items.append((score, item))

                # Sort by score (highest first)
                scored_items.sort(key=lambda x: x[0], reverse=True)
                result['items'] = [item for score, item in scored_items]
                result['count'] = len(result['items'])

            current_app.logger.info(f"Found {len(result['items'])} comic items via image search")
            return result

        except requests.RequestException as e:
            current_app.logger.error(f"eBay image search request error: {e}")
            return {'success': False, 'error': f'API request failed: {str(e)}'}
        except Exception as e:
            current_app.logger.error(f"eBay image search error: {e}")
            return {'success': False, 'error': str(e)}

    def _get_trading_credentials(self, environment=None):
        env = (environment or self.environment or 'production').lower()
        cfg = current_app.config
        if env == 'sandbox':
            return {
                'app_id': cfg.get('EBAY_SANDBOX_APP_ID') or os.getenv('EBAY_SANDBOX_APP_ID'),
                'dev_id': cfg.get('EBAY_SANDBOX_DEV_ID') or os.getenv('EBAY_SANDBOX_DEV_ID'),
                'cert_id': cfg.get('EBAY_SANDBOX_CERT_ID') or os.getenv('EBAY_SANDBOX_CERT_ID'),
                'token': cfg.get('EBAY_SANDBOX_TOKEN') or os.getenv('EBAY_SANDBOX_TOKEN'),
                'domain': 'api.sandbox.ebay.com'
            }
        return {
            'app_id': cfg.get('EBAY_PRODUCTION_APP_ID') or os.getenv('EBAY_PRODUCTION_APP_ID'),
            'dev_id': cfg.get('EBAY_PRODUCTION_DEV_ID') or os.getenv('EBAY_PRODUCTION_DEV_ID'),
            'cert_id': cfg.get('EBAY_PRODUCTION_CERT_ID') or os.getenv('EBAY_PRODUCTION_CERT_ID'),
            'token': cfg.get('EBAY_PRODUCTION_TOKEN') or os.getenv('EBAY_PRODUCTION_TOKEN'),
            'domain': 'api.ebay.com'
        }

    def _get_trading_connection(self, environment=None):
        creds = self._get_trading_credentials(environment)
        missing = [k for k, v in creds.items() if k != 'domain' and not v]
        if missing:
            raise RuntimeError(f"Missing eBay credentials for {environment or self.environment}: {', '.join(missing)}")
        return Trading(
            config_file=None,
            domain=creds['domain'],
            appid=creds['app_id'],
            devid=creds['dev_id'],
            certid=creds['cert_id'],
            token=creds['token'],
            warnings=True
        )

    def _execute_trading_call(self, call_name, payload, environment=None, mode='list', files=None):
        """Execute an eBay Trading API call with error handling.

        Args:
            call_name (str): Trading API verb (e.g. 'AddFixedPriceItem').
            payload (dict): Request body as a dict.
            environment (str): 'production' or 'sandbox'.
            mode (str): 'list', 'upload', etc. (for logging).
            files (dict, optional): Multipart file data for binary uploads,
                e.g. ``{'file': ('name.jpg', bytes_data, 'image/jpeg')}``.
        """
        env = (environment or self.environment or 'production').lower()
        current_app.logger.debug(
            "eBay Trading call=%s env=%s mode=%s payload_keys=%s",
            call_name,
            env,
            mode,
            list(payload.keys())
        )

        conn = self._get_trading_connection(env)
        try:
            response = conn.execute(call_name, payload, files=files)
        except TradingError as exc:
            # Log the XML request and response on error
            xml_request = None
            if hasattr(conn, 'request_xml'):
                xml_request = conn.request_xml
            elif hasattr(conn, 'request') and hasattr(conn.request, 'body'):
                xml_request = conn.request.body

            current_app.logger.error("eBay XML Request: %s", xml_request or 'Unable to retrieve request XML')
            current_app.logger.error("eBay XML Response: %s", conn.response.content if hasattr(conn.response, 'content') else 'N/A')
            current_app.logger.error(
                "TradingError during %s (%s): %s", call_name, env, exc,
                exc_info=True
            )
            raise
        except Exception as exc:
            current_app.logger.error(
                "Unexpected error during %s (%s): %s", call_name, env, exc,
                exc_info=True
            )
            raise

        ack = getattr(response.reply, 'Ack', None)
        warnings = getattr(response.reply, 'Errors', None) if ack == 'Warning' else None
        errors = getattr(response.reply, 'Errors', None) if ack not in ('Success', 'Warning') else None

        if errors:
            error_messages = []
            duplicate_item_id = None
            duplicate_title = None
            is_duplicate_error = False

            for err in errors if isinstance(errors, list) else [errors]:
                code = getattr(err, 'ErrorCode', 'UNKNOWN')
                msg = getattr(err, 'LongMessage', getattr(err, 'ShortMessage', 'Unknown error'))
                error_messages.append(f"[{code}] {msg}")

                # Check for duplicate listing error (code 21919067)
                if code == '21919067' or 'Duplicate Listing' in msg or 'duplicate listing' in msg.lower():
                    is_duplicate_error = True
                    # Try to extract existing item ID from message
                    # Pattern 1: "item already have/exists on eBay: Title (ItemID)" or "already have/exists on eBay: Title (ItemID)"
                    match = re.search(r'(?:item\s+)?(?:already have|already exists|exists) on eBay:\s*(.+?)\s*\((\d+)\)', msg, re.IGNORECASE)
                    if match:
                        duplicate_title = match.group(1).strip()
                        duplicate_item_id = match.group(2).strip()
                    else:
                        # Try alternate pattern: just the item ID in parentheses
                        match = re.search(r'\((\d{12,})\)', msg)
                        if match:
                            duplicate_item_id = match.group(1).strip()

            message = '; '.join(error_messages) or 'Trading API call failed'
            current_app.logger.error("eBay Trading %s failed: %s", call_name, message)

            # If it's a duplicate listing error, raise custom exception with helpful info
            if is_duplicate_error:
                raise EbayDuplicateListingError(message, duplicate_item_id, duplicate_title)

            raise RuntimeError(message)

        if warnings:
            warn_messages = []
            for warn in warnings if isinstance(warnings, list) else [warnings]:
                code = getattr(warn, 'ErrorCode', 'WARN')
                msg = getattr(warn, 'LongMessage', getattr(warn, 'ShortMessage', 'Unknown warning'))
                warn_messages.append(f"[{code}] {msg}")
            current_app.logger.warning(
                "eBay Trading %s returned warnings: %s",
                call_name,
                '; '.join(warn_messages)
            )

        item_id = getattr(response.reply, 'ItemID', None)
        current_app.logger.debug("eBay Trading %s succeeded env=%s item_id=%s", call_name, env, item_id)
        return response

    def list_comic(self, comic, environment=None, mode='list', overrides=None, schedule_time=None):
        """List a comic on eBay."""
        # Validate that comic has at least 1 image
        image_urls = getattr(comic, 'image_urls', [])

        valid_images = [url for url in image_urls if url and url.strip()]

        if not valid_images:
            current_app.logger.error(f"[list_comic] SKU {comic.sku}: No valid images found")
            raise ValueError('Cannot list item on eBay without at least 1 photo. Please add an image first.')

        current_app.logger.debug(f"[list_comic] SKU {comic.sku}: Found {len(valid_images)} valid images")

        # Upload images to eBay's servers first, getting back short hosted URLs
        ebay_picture_urls = self.upload_pictures(valid_images, environment=environment)
        if not ebay_picture_urls:
            raise RuntimeError('Failed to upload any images to eBay. Cannot create listing without pictures.')
        current_app.logger.info(f"[list_comic] SKU {comic.sku}: Uploaded {len(ebay_picture_urls)} images to eBay")

        # Pass eBay-hosted URLs into overrides so build_trading_item uses them
        overrides = overrides or {}
        overrides['_ebay_picture_urls'] = ebay_picture_urls

        payload = {'Item': build_trading_item(comic, overrides=overrides, mode=mode, schedule_time=schedule_time)}

        # Log if PictureDetails is in the payload
        if 'PictureDetails' in payload.get('Item', {}):
            pic_urls = payload['Item']['PictureDetails'].get('PictureURL', [])
            current_app.logger.debug(f"[list_comic] SKU {comic.sku}: Sending {len(pic_urls)} images to eBay in PictureDetails")
        else:
            current_app.logger.warning(f"[list_comic] SKU {comic.sku}: ⚠️ NO PictureDetails in payload!")

        response = self._execute_trading_call('AddFixedPriceItem', payload, environment=environment, mode=mode)
        return getattr(response.reply, 'ItemID', None)

    def update_listing(self, comic, environment=None, overrides=None, mode='list', schedule_time=None):
        if not comic.ebay_item_id:
            raise ValueError('Cannot update listing without ebay_item_id')

        # Upload images to eBay's servers
        image_urls = getattr(comic, 'image_urls', [])
        valid_images = [url for url in image_urls if url and url.strip()]
        current_app.logger.debug(f"[update_listing] SKU {comic.sku}: Found {len(valid_images)} valid images")

        if valid_images:
            ebay_picture_urls = self.upload_pictures(valid_images, environment=environment)
            if ebay_picture_urls:
                overrides = overrides or {}
                overrides['_ebay_picture_urls'] = ebay_picture_urls
                current_app.logger.info(f"[update_listing] SKU {comic.sku}: Uploaded {len(ebay_picture_urls)} images to eBay")

        payload = {'Item': build_trading_item(comic, overrides=overrides, mode=mode, include_item_id=True, schedule_time=schedule_time)}

        # Log if PictureDetails is in the payload
        if 'PictureDetails' in payload.get('Item', {}):
            pic_urls = payload['Item']['PictureDetails'].get('PictureURL', [])
            current_app.logger.debug(f"[update_listing] SKU {comic.sku}: Sending {len(pic_urls)} images to eBay")
        else:
            current_app.logger.warning(f"[update_listing] SKU {comic.sku}: ⚠️ NO PictureDetails in payload!")

        response = self._execute_trading_call('ReviseFixedPriceItem', payload, environment=environment, mode=mode)
        return getattr(response.reply, 'ItemID', comic.ebay_item_id)

    def upload_picture(self, image_url, environment=None):
        """Upload a single image to eBay via UploadSiteHostedPictures.

        Downloads the image from S3 using boto3 and uploads the raw bytes
        directly to eBay as a multipart binary upload.  This avoids all
        URL-related issues (presigned URL length, XML escaping of ``&``,
        private bucket access).

        Args:
            image_url (str): S3 URL of the image to upload.
            environment (str, optional): 'production' or 'sandbox'.

        Returns:
            str: eBay-hosted image URL, or None on failure.
        """
        from app.services.s3_service import s3_service
        import urllib.parse

        try:
            # ── 1. Download image bytes from S3 ────────────────────────
            parsed = urllib.parse.urlparse(image_url)
            s3_key = urllib.parse.unquote(parsed.path.lstrip('/'))
            bucket = s3_service.bucket_name

            if not bucket:
                current_app.logger.error("[upload_picture] S3 bucket not configured")
                return None

            current_app.logger.debug(f"[upload_picture] Downloading s3://{bucket}/{s3_key}")
            s3_obj = s3_service.client().get_object(Bucket=bucket, Key=s3_key)
            image_bytes = s3_obj['Body'].read()
            content_type = s3_obj.get('ContentType', 'image/jpeg')

            if not image_bytes:
                current_app.logger.error(f"[upload_picture] Empty image data for {image_url}")
                return None

            # ── 2. Determine filename from the S3 key ──────────────────
            filename = s3_key.rsplit('/', 1)[-1] if '/' in s3_key else s3_key

            # ── 3. Upload binary to eBay ───────────────────────────────
            payload = {
                'PictureName': filename,
            }
            files = {
                'file': (filename, image_bytes, content_type),
            }

            response = self._execute_trading_call(
                'UploadSiteHostedPictures', payload,
                environment=environment, mode='upload',
                files=files,
            )

            site_hosted = getattr(response.reply, 'SiteHostedPictureDetails', None)
            if site_hosted:
                full_url = getattr(site_hosted, 'FullURL', None)
                if full_url:
                    current_app.logger.info(f"[upload_picture] Uploaded {filename} → {full_url}")
                    return str(full_url)

            current_app.logger.error(f"[upload_picture] No FullURL in response for {image_url}")
            return None

        except Exception as e:
            current_app.logger.error(f"[upload_picture] Failed to upload {image_url}: {e}")
            return None

    def upload_pictures(self, image_urls, environment=None):
        """Upload multiple images to eBay, returning eBay-hosted URLs.

        Args:
            image_urls (list): List of S3 image URLs.
            environment (str, optional): 'production' or 'sandbox'.

        Returns:
            list: eBay-hosted URLs (only successful uploads). Max 12 per eBay limits.
        """
        ebay_urls = []
        for url in image_urls[:12]:  # eBay max 12 pictures
            hosted_url = self.upload_picture(url, environment=environment)
            if hosted_url:
                ebay_urls.append(hosted_url)
        return ebay_urls

    def get_item(self, item_id, environment=None):
        """
        Get item details from eBay using GetItem Trading API call.

        Args:
            item_id (str): The eBay Item ID to retrieve
            environment (str, optional): 'production' or 'sandbox'

        Returns:
            dict: Item details if found, None if not found
        """
        if not item_id:
            return None

        try:
            payload = {
                'ItemID': item_id,
                'DetailLevel': 'ReturnAll'
            }
            response = self._execute_trading_call('GetItem', payload, environment=environment, mode='read')

            if response and hasattr(response.reply, 'Item'):
                item = response.reply.Item
                return {
                    'ItemID': getattr(item, 'ItemID', None),
                    'Title': getattr(item, 'Title', None),
                    'ListingStatus': getattr(item, 'SellingStatus', {}).get('ListingStatus') if hasattr(item, 'SellingStatus') else None,
                    'Quantity': getattr(item, 'Quantity', None),
                    'QuantitySold': getattr(item, 'SellingStatus', {}).get('QuantitySold') if hasattr(item, 'SellingStatus') else None,
                    'CurrentPrice': getattr(item, 'SellingStatus', {}).get('CurrentPrice') if hasattr(item, 'SellingStatus') else None,
                    'ListingType': getattr(item, 'ListingType', None),
                    'StartTime': getattr(item, 'ListingDetails', {}).get('StartTime') if hasattr(item, 'ListingDetails') else None,
                    'EndTime': getattr(item, 'ListingDetails', {}).get('EndTime') if hasattr(item, 'ListingDetails') else None,
                }
            return None

        except Exception as e:
            current_app.logger.warning(f"Failed to get eBay item {item_id}: {e}")
            # If item not found or error, return None (item doesn't exist)
            return None

    def end_listing(self, comic, reason='NotAvailable', environment=None):
        if not comic.ebay_item_id:
            raise ValueError('Cannot end listing without ebay_item_id')
        payload = {'EndingReason': reason, 'ItemID': comic.ebay_item_id}
        self._execute_trading_call('EndFixedPriceItem', payload, environment=environment, mode='end')


    def get_call_statistics(self):
        """
        Get local call statistics from in-memory tracking.

        This is a fallback method that tracks API calls made by this service instance.
        Note: This only tracks calls made in the current process/worker.

        Returns:
            dict: Call statistics including counts by type
        """
        return {
            'calls': self._call_counts.copy(),
            'environment': self.environment,
            'note': 'These are local in-memory counts for this worker process only.'
        }

    def get_category_tree_id(self, marketplace_id='EBAY_US'):
        """
        Map marketplace ID to eBay category tree ID.

        Args:
            marketplace_id (str): The marketplace ID (e.g., 'EBAY_US')

        Returns:
            str: The category tree ID for the marketplace
        """
        # eBay Category Tree IDs
        # Reference: https://developer.ebay.com/api-docs/commerce/taxonomy/overview.html
        marketplace_to_tree_id = {
            'EBAY_US': '0',      # United States
            'EBAY_GB': '3',      # United Kingdom
            'EBAY_CA': '2',      # Canada (English)
            'EBAY_AU': '15',     # Australia
            'EBAY_DE': '77',     # Germany
            'EBAY_FR': '71',     # France
            'EBAY_IT': '101',    # Italy
            'EBAY_ES': '186',    # Spain
            'EBAY_MOTORS_US': '100',  # eBay Motors US
        }
        return marketplace_to_tree_id.get(marketplace_id, '0')  # Default to US

    def get_category_tree(self, marketplace_id='EBAY_US'):
        """
        Get the eBay category tree for a specific marketplace.

        Args:
            marketplace_id (str): The marketplace ID (e.g., 'EBAY_US')

        Returns:
            dict: Category tree data or error info
        """
        token = self._get_oauth_token()
        if not token:
            return {'error': 'Failed to obtain OAuth token'}

        try:
            # Get the numeric category tree ID
            category_tree_id = self.get_category_tree_id(marketplace_id)

            # Use Commerce Taxonomy API
            url = f"https://api.ebay.com/commerce/taxonomy/v1/category_tree/{category_tree_id}"

            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }

            response = requests.get(url, headers=headers, timeout=10)

            if response.status_code == 200:
                return response.json()
            else:
                current_app.logger.error(f"Category tree request failed: {response.status_code} - {response.text}")
                return {'error': f'Request failed with status {response.status_code}'}

        except Exception as e:
            current_app.logger.error(f"Error fetching category tree: {e}")
            return {'error': str(e)}

    def _load_category_cache(self):
        """Load category tree cache from file."""
        try:
            if not os.path.exists(self.category_cache_file):
                current_app.logger.info(f"Category cache file not found: {self.category_cache_file}")
                return False

            with open(self.category_cache_file, 'r') as f:
                cache_data = json.load(f)
                self.category_tree_cache = cache_data.get('tree')
                self.category_tree_version = cache_data.get('version')
                cached_time = cache_data.get('cached_at')
                current_app.logger.info(f"Loaded category cache from {self.category_cache_file}: version={self.category_tree_version}, cached_at={cached_time}")
                return True
        except json.JSONDecodeError as e:
            current_app.logger.error(f"Invalid JSON in category cache file: {e}")
        except Exception as e:
            current_app.logger.error(f"Error loading category cache: {e}")
            import traceback
            current_app.logger.error(traceback.format_exc())
        return False

    def _save_category_cache(self, tree_data, version):
        """Save category tree cache to file."""
        try:
            cache_data = {
                'tree': tree_data,
                'version': version,
                'cached_at': datetime.now().isoformat()
            }
            # Ensure the directory exists
            cache_dir = os.path.dirname(self.category_cache_file)
            if cache_dir:  # Only create if there's a directory component
                os.makedirs(cache_dir, exist_ok=True)

            # Write to a temp file first, then rename (atomic operation)
            temp_file = self.category_cache_file + '.tmp'
            with open(temp_file, 'w') as f:
                json.dump(cache_data, f, indent=2)

            # Atomic rename
            os.replace(temp_file, self.category_cache_file)

            self.category_tree_cache = tree_data
            self.category_tree_version = version
            current_app.logger.info(f"Saved category cache to {self.category_cache_file}: version={version}, size={len(json.dumps(cache_data))} bytes")
            return True
        except Exception as e:
            current_app.logger.error(f"Error saving category cache: {e}")
            import traceback
            current_app.logger.error(traceback.format_exc())
        return False

    def _fetch_full_category_tree(self, marketplace_id='EBAY_US', max_depth=2):
        """
        Fetch the full category tree from eBay.
        eBay's default tree response already includes the full nested hierarchy.
        We just need to normalize the structure.

        Args:
            marketplace_id: The marketplace ID (e.g., 'EBAY_US')
            max_depth: Not used - kept for API compatibility

        Returns:
            dict: Complete category tree with all subcategories
        """
        current_app.logger.info(f"Fetching full category tree for {marketplace_id}")

        token = self._get_oauth_token()
        if not token:
            return {'error': 'Failed to obtain OAuth token'}

        try:
            category_tree_id = self.get_category_tree_id(marketplace_id)

            # Get tree - eBay returns the FULL nested tree in one call!
            tree_url = f"https://api.ebay.com/commerce/taxonomy/v1/category_tree/{category_tree_id}"
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }

            response = requests.get(tree_url, headers=headers, timeout=10)
            if response.status_code != 200:
                return {'error': f'Failed to get tree: {response.status_code}'}

            tree_data = response.json()
            version = tree_data.get('categoryTreeVersion')
            root_node = tree_data.get('rootCategoryNode', {})

            current_app.logger.info(f"Tree version: {version}")

            # Normalize the structure recursively
            normalized_root = self._normalize_category_node(root_node)

            # Build result
            result = {
                'categoryTreeId': category_tree_id,
                'categoryTreeVersion': version,
                'categoryTreeNode': {
                    'categoryId': '0',
                    'categoryName': 'All Categories',
                    'childCategoryTreeNodes': normalized_root.get('childCategoryTreeNodes', [])
                }
            }

            # Count total categories
            total = self._count_categories(result['categoryTreeNode'])
            current_app.logger.info(f"Successfully fetched complete tree with {total} total categories")

            # Save to cache
            self._save_category_cache(result, version)

            return result

        except Exception as e:
            current_app.logger.error(f"Error fetching full category tree: {e}")
            import traceback
            current_app.logger.error(traceback.format_exc())
            return {'error': str(e)}

    def _lookup_category_name(self, category_id):
        """
        Look up a category name from the cached category tree.

        Args:
            category_id: The category ID to look up

        Returns:
            str: Category name if found, empty string otherwise
        """
        if not category_id or not self.category_tree_cache:
            return ''

        # Convert to string for comparison
        category_id_str = str(category_id)

        def search_tree(node):
            """Recursively search the tree for the category ID."""
            if not node:
                return None

            # Check current node
            node_id = str(node.get('categoryId', ''))
            if node_id == category_id_str:
                return node.get('categoryName', '')

            # Search children
            for child in node.get('childCategoryTreeNodes', []):
                result = search_tree(child)
                if result:
                    return result

            return None

        # Start search from root
        root_node = self.category_tree_cache.get('categoryTreeNode')
        if root_node:
            return search_tree(root_node) or ''

        return ''

    def _normalize_category_node(self, node):
        """
        Normalize eBay's category node structure.
        eBay nests info in a 'category' object - extract to flat structure.
        """
        if not node:
            return None

        # Extract from nested 'category' object
        category_obj = node.get('category', {})
        cat_id = category_obj.get('categoryId')
        cat_name = category_obj.get('categoryName', 'Unknown')

        # Normalize children recursively
        children = node.get('childCategoryTreeNodes', [])
        normalized_children = []

        for child_node in children:
            normalized_child = self._normalize_category_node(child_node)
            if normalized_child:
                normalized_children.append(normalized_child)

        return {
            'categoryId': cat_id,
            'categoryName': cat_name,
            'childCategoryTreeNodes': normalized_children
        }

    def _count_categories(self, node):
        """Count total categories in a tree."""
        if not node:
            return 0
        count = 1
        for child in node.get('childCategoryTreeNodes', []):
            count += self._count_categories(child)
        return count

    def _fetch_category_subtree_recursive(self, tree_id, category_id, headers, current_depth, max_depth):
        """
        Recursively fetch a category and all its children.

        Args:
            tree_id: The category tree ID
            category_id: Current category ID to fetch
            headers: HTTP headers with auth token
            current_depth: Current recursion depth
            max_depth: Maximum depth to traverse

        Returns:
            dict: Category node with all children populated
        """
        if current_depth >= max_depth:
            current_app.logger.debug(f"Reached max depth at category {category_id}")
            return None

        try:
            url = f"https://api.ebay.com/commerce/taxonomy/v1/category_tree/{tree_id}/get_category_subtree"
            params = {'category_id': category_id}

            response = requests.get(url, headers=headers, params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()
                node = data.get('categorySubtreeNode', data.get('categoryTreeNode'))

                if not node:
                    return None

                # Get basic node info - eBay nests in a 'category' object
                category_obj = node.get('category', {})
                node_id = category_obj.get('categoryId')
                node_name = category_obj.get('categoryName', 'Unknown')
                children = node.get('childCategoryTreeNodes', [])

                current_app.logger.debug(f"Fetched {node_name} ({node_id}): {len(children)} children")

                # Format the node
                formatted_node = {
                    'categoryId': node_id,
                    'categoryName': node_name,
                    'childCategoryTreeNodes': []
                }

                # Recursively fetch children if not at max depth
                if children and current_depth < max_depth - 1:
                    for child_node in children:
                        # Extract from nested 'category' object
                        child_cat = child_node.get('category', {})
                        child_id = child_cat.get('categoryId')
                        if child_id:
                            # Fetch child's full subtree
                            full_child_node = self._fetch_category_subtree_recursive(
                                tree_id, child_id, headers, current_depth + 1, max_depth
                            )
                            if full_child_node:
                                formatted_node['childCategoryTreeNodes'].append(full_child_node)
                            time.sleep(0.1)  # Rate limiting
                else:
                    # At max depth or no children, just add child info without recursing
                    for child_node in children:
                        child_cat = child_node.get('category', {})
                        child_id = child_cat.get('categoryId')
                        child_name = child_cat.get('categoryName', 'Unknown')
                        if child_id and child_name:
                            formatted_node['childCategoryTreeNodes'].append({
                                'categoryId': child_id,
                                'categoryName': child_name,
                                'childCategoryTreeNodes': []
                            })

                return formatted_node
            else:
                current_app.logger.warning(f"Failed to fetch category {category_id}: {response.status_code}")
                return None

        except Exception as e:
            current_app.logger.error(f"Error in recursive fetch for category {category_id}: {e}")
            return None

    def get_root_categories(self, marketplace_id='EBAY_US'):
        """
        Get category tree - uses cache if available and up-to-date.

        Args:
            marketplace_id (str): The marketplace ID (e.g., 'EBAY_US')

        Returns:
            dict: Complete category tree (from cache or freshly fetched)
        """
        try:
            # Load cache if not already loaded
            if self.category_tree_cache is None:
                self._load_category_cache()

            # Check if we have cached data
            if self.category_tree_cache and self.category_tree_version:
                # Verify the cached version is still current
                token = self._get_oauth_token()
                if token:
                    category_tree_id = self.get_category_tree_id(marketplace_id)
                    tree_url = f"https://api.ebay.com/commerce/taxonomy/v1/category_tree/{category_tree_id}"
                    headers = {
                        'Authorization': f'Bearer {token}',
                        'Content-Type': 'application/json'
                    }

                    response = requests.get(tree_url, headers=headers, timeout=10)
                    if response.status_code == 200:
                        current_version = response.json().get('categoryTreeVersion')

                        if current_version == self.category_tree_version:
                            current_app.logger.info(f"Using cached category tree (version {current_version})")
                            return self.category_tree_cache
                        else:
                            current_app.logger.info(f"Category tree version changed: {self.category_tree_version} -> {current_version}")

            # Cache miss or outdated - fetch full tree
            current_app.logger.info("Fetching complete category tree from eBay...")
            result = self._fetch_full_category_tree(marketplace_id)

            if 'error' not in result:
                return result
            else:
                return {'error': result.get('error')}

        except Exception as e:
            current_app.logger.error(f"Error in get_root_categories: {e}")
            import traceback
            current_app.logger.error(traceback.format_exc())
            return {'error': str(e)}

    def get_category_children(self, category_id, marketplace_id='EBAY_US'):
        """
        Get children of a specific category.

        Args:
            category_id (str): The parent category ID
            marketplace_id (str): The marketplace ID (e.g., 'EBAY_US')

        Returns:
            dict: Children categories
        """
        token = self._get_oauth_token()
        if not token:
            return {'error': 'Failed to obtain OAuth token'}

        try:
            # Get the numeric category tree ID
            category_tree_id = self.get_category_tree_id(marketplace_id)

            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }

            # Get the category subtree for this specific category
            url = f"https://api.ebay.com/commerce/taxonomy/v1/category_tree/{category_tree_id}/get_category_subtree"
            params = {'category_id': category_id}

            response = requests.get(url, headers=headers, params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()

                # Log the response structure for debugging
                current_app.logger.info(f"Category children API response keys: {list(data.keys())}")

                category_subtree = data.get('categorySubtreeNode', data.get('categoryTreeNode'))

                if category_subtree:
                    children = category_subtree.get('childCategoryTreeNodes', [])

                    current_app.logger.info(f"Found {len(children)} children for category {category_id}")

                    # Format children - add hasChildren flag
                    formatted_children = []
                    for idx, child in enumerate(children):
                        # Log first child for debugging
                        if idx == 0:
                            current_app.logger.info(f"First child structure: {list(child.keys()) if isinstance(child, dict) else type(child)}")

                        # Try multiple ways to extract category info
                        child_id = None
                        child_name = None
                        child_children = []

                        if isinstance(child, dict):
                            # Direct properties
                            child_id = child.get('categoryId') or child.get('categoryTreeNodeId')
                            child_name = child.get('categoryName') or child.get('categoryTreeNodeName')
                            child_children = child.get('childCategoryTreeNodes', [])

                            # If not found, check nested 'category' object
                            if not child_id or not child_name:
                                nested_cat = child.get('category', {})
                                if nested_cat:
                                    child_id = child_id or nested_cat.get('categoryId')
                                    child_name = child_name or nested_cat.get('categoryName')

                        # Only add if we have valid ID and name
                        if child_id and child_name:
                            formatted_children.append({
                                'categoryId': str(child_id),
                                'categoryName': str(child_name),
                                'hasChildren': len(child_children) > 0
                            })
                        else:
                            current_app.logger.warning(f"Skipping child with missing data: id={child_id}, name={child_name}")

                    current_app.logger.info(f"Formatted {len(formatted_children)} valid children")

                    return {
                        'success': True,
                        'children': formatted_children
                    }
                else:
                    current_app.logger.warning(f"No category subtree found in response")
                    return {'success': True, 'children': []}
            else:
                current_app.logger.error(f"Get children failed: {response.status_code} - {response.text}")
                return {'error': f'Request failed with status {response.status_code}'}

        except Exception as e:
            current_app.logger.error(f"Error fetching category children: {e}")
            import traceback
            current_app.logger.error(traceback.format_exc())
            return {'error': str(e)}

    def search_categories(self, query, marketplace_id='EBAY_US'):
        """
        Search for eBay categories by name.

        Args:
            query (str): Search query string
            marketplace_id (str): The marketplace ID (e.g., 'EBAY_US')

        Returns:
            dict: Matching categories or error info
        """
        token = self._get_oauth_token()
        if not token:
            return {'error': 'Failed to obtain OAuth token'}

        try:
            # Get the numeric category tree ID directly
            category_tree_id = self.get_category_tree_id(marketplace_id)

            # Use Commerce Taxonomy API to search categories
            url = f"https://api.ebay.com/commerce/taxonomy/v1/category_tree/{category_tree_id}/get_category_suggestions"

            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }

            params = {
                'q': query
            }

            response = requests.get(url, headers=headers, params=params, timeout=10)

            if response.status_code == 200:
                return response.json()
            else:
                current_app.logger.error(f"Category search failed: {response.status_code} - {response.text}")
                return {'error': f'Request failed with status {response.status_code}'}

        except Exception as e:
            current_app.logger.error(f"Error searching categories: {e}")
            return {'error': str(e)}


# Singleton instance
ebay_service = EbayService()


