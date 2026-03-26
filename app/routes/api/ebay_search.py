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
import requests


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
    """Proxy S3 images to avoid CORS issues in browser.

    Acts as a proxy server for S3 images, allowing the frontend to access
    images without running into Cross-Origin Resource Sharing (CORS) restrictions.

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
        500: Failed to fetch image from S3

    Example Request:
        GET /proxy-image?url=https://s3.amazonaws.com/bucket/production/images/1001_1.jpg

    Security:
        - Only allows S3 URLs from app bucket
        - Rejects external URLs to prevent abuse
        - Sets cache headers for performance

    Note:
        - Required for eBay image search results display
        - Caches images for 24 hours (86400 seconds)
        - 10 second timeout on S3 requests
        - Preserves original image content type
    """
    image_url = request.args.get('url')
    if not image_url:
        return jsonify({'error': 'URL parameter required'}), 400

    # Security: Only allow S3 URLs from our bucket
    s3_bucket = os.environ.get('S3_BUCKET_NAME', '')
    if not ('s3.amazonaws.com' in image_url and (not s3_bucket or s3_bucket in image_url)):
        return jsonify({'error': 'Invalid image URL'}), 403

    try:
        # Fetch image from S3
        response = requests.get(image_url, timeout=10)
        response.raise_for_status()

        # Return image with proper content type
        return response.content, 200, {
            'Content-Type': response.headers.get('Content-Type', 'image/jpeg'),
            'Cache-Control': 'public, max-age=86400'
        }
    except Exception as e:
        current_app.logger.error(f"Error proxying image {image_url}: {e}")
        return jsonify({'error': 'Failed to fetch image'}), 500
