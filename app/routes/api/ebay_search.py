"""eBay Search routes - Price lookup and visual search operations.

This module handles:
- eBay price lookup (completed items search)
- Active listings search
- Visual search by image
- Image proxy for CORS

All functions include type hints and comprehensive docstrings for better IDE support.
"""
from typing import Dict, Tuple
from flask import request, jsonify, current_app, Response
from app.routes.api import api_bp
from app.routes.auth import login_required, csrf_required
from app.services.ebay_service import ebay_service
import os


@api_bp.route('/ebay/lookup-price', methods=['POST'])
@login_required
@csrf_required
def lookup_ebay_price() -> Response:
    """Search eBay completed items for price research.

    Searches recently sold items on eBay to help determine appropriate pricing.
    Uses eBay Finding API to search completed/sold listings.

    Request Body (JSON):
        {
            "title": str,               # Comic title to search
            "condition": Optional[str], # Condition filter (e.g., "Near Mint")
            "limit": Optional[int]      # Max results (5-100, default 20)
        }

    Returns:
        Response: Flask JSON response containing:
            - success (bool): Whether search succeeded
            - results (list): List of sold items with:
                - title (str): Item title
                - soldPrice (str): Final sale price
                - soldDate (str): Date sold
                - condition (str): Item condition
                - url (str): eBay item URL
            - count (int): Number of results returned
            - rate_limit (bool, optional): If API limit hit
            - fallback_url (str, optional): Manual search URL if rate limited
            - error (str, optional): Error message if failed

    Status Codes:
        200: Search completed successfully
        400: Title required or invalid request
        500: eBay API error or server error

    Example Request:
        {
            "title": "Amazing Spider-Man 300",
            "condition": "Near Mint",
            "limit": 20
        }

    Example Response:
        {
            "success": true,
            "results": [
                {
                    "title": "Amazing Spider-Man #300",
                    "soldPrice": "$45.99",
                    "soldDate": "2026-01-25",
                    "condition": "Near Mint",
                    "url": "https://ebay.com/itm/..."
                }
            ],
            "count": 15
        }

    Note:
        - Results limited to items sold in past 90 days
        - Prices show actual sale price, not asking price
        - Useful for competitive pricing research
        - Falls back to manual search URL if API rate limited
    """
    try:
        data = request.get_json()
        title = data.get('title')
        condition = data.get('condition')
        limit = data.get('limit', 20)

        if not title:
            return jsonify({'success': False, 'error': 'Comic title is required'}), 400

        # Validate limit
        try:
            limit = int(limit)
            if limit < 5 or limit > 100:
                limit = 20
        except (ValueError, TypeError):
            limit = 20

        # Search eBay for completed items
        result = ebay_service.search_completed_items(title, condition=condition, limit=limit)

        # If API limit error, provide fallback URL
        if not result.get('success') and result.get('rate_limit'):
            fallback = ebay_service.get_sold_prices_url(title, condition)
            result['fallback_url'] = fallback['url']
            result['fallback_message'] = fallback['message']

        return jsonify(result)

    except Exception as e:
        current_app.logger.error(f"Error looking up eBay price: {e}")
        return jsonify({'success': False, 'error': 'Failed to lookup eBay prices'}), 500


@api_bp.route('/ebay/search-active', methods=['POST'])
@login_required
@csrf_required
def search_active_items() -> Response:
    """Search active (currently listed) items on eBay.

    Searches current eBay listings to see what's currently available and at what prices.
    Useful for competitive analysis and market research.

    Request Body (JSON):
        {
            "title": str,               # Comic title to search
            "condition": Optional[str], # Condition filter
            "limit": Optional[int]      # Max results (5-100, default 20)
        }

    Returns:
        Response: Flask JSON response containing:
            - success (bool): Whether search succeeded
            - results (list): List of active listings
            - count (int): Number of results
            - error (str, optional): Error message if failed

    Status Codes:
        200: Search completed successfully
        400: Title required
        500: eBay API error

    Example Response:
        {
            "success": true,
            "results": [
                {
                    "title": "Amazing Spider-Man #300",
                    "currentPrice": "$49.99",
                    "condition": "Very Good",
                    "url": "https://ebay.com/itm/..."
                }
            ],
            "count": 12
        }

    Note:
        - Shows currently available items only
        - Prices are asking prices, not sold prices
        - Use for competitive pricing and availability research
    """
    try:
        data = request.get_json()
        title = data.get('title')
        condition = data.get('condition')
        limit = data.get('limit', 20)

        if not title:
            return jsonify({'success': False, 'error': 'Comic title is required'}), 400

        # Validate limit
        try:
            limit = int(limit)
            if limit < 5 or limit > 100:
                limit = 20
        except (ValueError, TypeError):
            limit = 20

        # Search eBay for active listings
        result = ebay_service.search_active_items(title, condition=condition, limit=limit)

        return jsonify(result)

    except Exception as e:
        current_app.logger.error(f"Error searching active eBay listings: {e}")
        return jsonify({'success': False, 'error': 'Failed to search active eBay listings'}), 500


@api_bp.route('/ebay/search-marketplace', methods=['POST'])
@login_required
@csrf_required
def search_marketplace() -> Response:
    """Search all of eBay marketplace using the Browse API.

    Uses the Browse API text search which has separate rate limits
    from the Finding API. Returns active listings from any seller.

    Request Body (JSON):
        {
            "title": str,                    # Search keywords
            "limit": Optional[int],          # Max results (1-50, default 12)
            "sort_by_title": Optional[str],  # If set, results re-ranked by title
                                             # similarity to this string. Defaults
                                             # to ``title`` so the closest comic
                                             # listings surface first.
        }

    Returns:
        Response: Flask JSON response with search results.
    """
    try:
        data = request.get_json()
        title = data.get('title')
        limit = data.get('limit', 12)
        sort_by_title = data.get('sort_by_title', title)

        if not title:
            return jsonify({'success': False, 'error': 'Search query is required'}), 400

        try:
            limit = max(1, min(50, int(limit)))
        except (ValueError, TypeError):
            limit = 12

        result = ebay_service.search_marketplace(
            title, limit=limit, sort_by_title=sort_by_title
        )
        return jsonify(result)

    except Exception as e:
        current_app.logger.error(f"Error searching eBay marketplace: {e}")
        return jsonify({'success': False, 'error': 'Failed to search eBay marketplace'}), 500


@api_bp.route('/ebay/search-by-image', methods=['POST'])
@login_required
@csrf_required
def search_by_image() -> Response:
    """Search eBay using visual/image recognition to find similar items.

    Upload an image and find visually similar items on eBay. Uses eBay's
    Browse API for image-based search capabilities.

    Request Body (JSON):
        {
            "image": str,               # Base64 encoded image data
            "title": Optional[str],     # Optional title for filtering results
            "limit": Optional[int]      # Max results (5-100, default 20)
        }

    Returns:
        Response: Flask JSON response containing:
            - success (bool): Whether search succeeded
            - results (list): List of visually similar items
            - count (int): Number of results
            - error (str, optional): Error message if failed

    Status Codes:
        200: Search completed successfully
        400: Image data required
        500: eBay API error or upload failed

    Example Request:
        {
            "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
            "title": "Spider-Man",
            "limit": 20
        }

    Example Response:
        {
            "success": true,
            "results": [
                {
                    "title": "Amazing Spider-Man #300",
                    "price": "$45.99",
                    "imageUrl": "https://...",
                    "itemUrl": "https://ebay.com/itm/..."
                }
            ],
            "count": 18
        }

    Note:
        - Image is uploaded to eBay for comparison
        - Results ordered by visual similarity
        - Optional title filter helps narrow results
        - Supports JPEG, PNG, GIF formats
        - Maximum image size: 10MB
    """
    try:
        data = request.get_json()
        image_data = data.get('image')
        title = data.get('title', '')
        limit = data.get('limit', 20)

        if not image_data:
            return jsonify({'success': False, 'error': 'Image data is required'}), 400

        # Validate limit
        try:
            limit = max(5, min(100, int(limit)))
        except (ValueError, TypeError):
            limit = 20

        # Remove data URL prefix if present
        if ',' in image_data:
            image_data = image_data.split(',', 1)[1]

        # Search eBay by image with configurable limit and optional similarity sorting
        result = ebay_service.search_by_image(image_data, limit=limit, sort_by_title=title)

        return jsonify(result)

    except Exception as e:
        current_app.logger.error(f"Error searching eBay by image route: {e}")
        return jsonify({'success': False, 'error': 'Failed to search eBay by image'}), 500


@api_bp.route('/proxy-image', methods=['GET'])
@login_required
def proxy_image() -> Tuple[bytes, int, Dict[str, str]]:
    """Proxy S3 images through the server using IAM credentials.

    The S3 bucket blocks all public access, so the browser cannot load images
    directly. This route fetches images via the boto3 S3 client (IAM-authenticated)
    and streams them to the authenticated user.

    Query Parameters:
        url (str): S3 image URL to proxy

    Returns:
        Tuple: (image_bytes, status_code, headers)
            - image_bytes: Raw image data
            - status_code: HTTP status (200 or error code)
            - headers: Content-Type and Cache-Control headers

    Status Codes:
        200: Image successfully proxied
        400: URL parameter missing
        403: URL not from allowed S3 bucket (security)
        404: Image not found in S3
        500: Failed to fetch image from S3

    Example Request:
        GET /api/proxy-image?url=https://bucket.s3.amazonaws.com/users/brian/images/1001_1.jpg

    Security:
        - Only allows S3 URLs from the app's configured bucket
        - Rejects external URLs to prevent abuse
        - Requires authentication (login_required)

    Note:
        - Uses boto3 S3 client with IAM credentials (bucket is private)
        - Browser caches images for 7 days (604800 seconds)
        - Content type inferred from S3 metadata or file extension
    """
    import urllib.parse

    image_url = request.args.get('url')
    if not image_url:
        return jsonify({'error': 'URL parameter required'}), 400

    # Security: Only allow S3 URLs from our bucket
    s3_bucket = current_app.config.get('S3_BUCKET', os.environ.get('S3_BUCKET_NAME', ''))
    if not s3_bucket or 's3.amazonaws.com' not in image_url or s3_bucket not in image_url:
        return jsonify({'error': 'Invalid image URL'}), 403

    try:
        # Extract S3 key from the URL
        parsed = urllib.parse.urlparse(image_url)
        # URL format: https://{bucket}.s3.amazonaws.com/{key}
        s3_key = urllib.parse.unquote(parsed.path.lstrip('/'))

        # Fetch image from S3 using IAM-authenticated boto3 client
        from app.services.s3_service import s3_service
        response = s3_service.client().get_object(Bucket=s3_bucket, Key=s3_key)
        body = response['Body'].read()

        # Determine content type from S3 metadata or file extension
        content_type = response.get('ContentType', '')
        if not content_type or content_type == 'binary/octet-stream':
            if s3_key.endswith('.webp'):
                content_type = 'image/webp'
            elif s3_key.endswith('.png'):
                content_type = 'image/png'
            elif s3_key.endswith('.gif'):
                content_type = 'image/gif'
            else:
                content_type = 'image/jpeg'

        return body, 200, {
            'Content-Type': content_type,
            'Cache-Control': 'public, max-age=604800'
        }
    except Exception as e:
        error_code = getattr(e, 'response', {}).get('Error', {}).get('Code', '')
        if error_code in ('NoSuchKey', '404'):
            return jsonify({'error': 'Image not found'}), 404
        current_app.logger.error(f"Error proxying image {image_url}: {e}")
        return jsonify({'error': 'Failed to fetch image'}), 500
