#!/bin/bash
#
# SSL Setup Script for Listing App
# Sets up Let's Encrypt SSL certificate with automatic renewal
#
# Usage: sudo ./setup-ssl.sh [domain]
#        Or run without arguments to be prompte# Application name - can be overridden with environment variable
APP_NAME="${APP_NAME:-rampe}"
#
# MANUAL CERTIFICATE REUSE INSTRUCTIONS
# ======================================
#
# If you already have certificates backed up and want to reuse them:
#
# METHOD 1: Restore full Let's Encrypt backup
# --------------------------------------------
# 1. Restore the backup:
#    sudo tar -xzf ~/redeploy/latest/ssl/letsencrypt_full_backup.tar.gz -C /
#
# 2. Verify certificates exist:
#    sudo ls -la /etc/letsencrypt/live/YOUR_DOMAIN/
#
# 3. Test nginx config:
#    sudo nginx -t
#
# 4. Reload nginx:
#    sudo systemctl reload nginx
#
# 5. Skip running this script - certificates already installed!
#
# METHOD 2: Manual certificate installation
# ------------------------------------------
# 1. Copy certificate files:
#    sudo mkdir -p /etc/letsencrypt/live/YOUR_DOMAIN
#    sudo cp ~/redeploy/latest/ssl/fullchain.pem /etc/letsencrypt/live/YOUR_DOMAIN/
#    sudo cp ~/redeploy/latest/ssl/privkey.pem /etc/letsencrypt/live/YOUR_DOMAIN/
#    sudo cp ~/redeploy/latest/ssl/cert.pem /etc/letsencrypt/live/YOUR_DOMAIN/
#    sudo cp ~/redeploy/latest/ssl/chain.pem /etc/letsencrypt/live/YOUR_DOMAIN/
#
# 2. Set permissions:
#    sudo chmod 644 /etc/letsencrypt/live/YOUR_DOMAIN/*.pem
#    sudo chmod 600 /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem
#    sudo chown -R root:root /etc/letsencrypt/live/YOUR_DOMAIN
#
# 3. Verify nginx SSL config (should already be set):
#    sudo grep ssl_certificate /etc/nginx/sites-available/${APP_NAME}
#
# 4. Test and reload:
#    sudo nginx -t
#    sudo systemctl reload nginx
#
# METHOD 3: Use without Let's Encrypt path
# -----------------------------------------
# If you want to use certificates without the /etc/letsencrypt path:
#
# 1. Copy to standard SSL locations:
#    sudo cp ~/redeploy/latest/ssl/fullchain.pem /etc/ssl/certs/YOUR_DOMAIN.crt
#    sudo cp ~/redeploy/latest/ssl/privkey.pem /etc/ssl/private/YOUR_DOMAIN.key
#    sudo chmod 644 /etc/ssl/certs/YOUR_DOMAIN.crt
#    sudo chmod 600 /etc/ssl/private/YOUR_DOMAIN.key
#
# 2. Update nginx config (/etc/nginx/sites-available/${APP_NAME}):
#    ssl_certificate /etc/ssl/certs/YOUR_DOMAIN.crt;
#    ssl_certificate_key /etc/ssl/private/YOUR_DOMAIN.key;
#
# 3. Reload nginx:
#    sudo nginx -t && sudo systemctl reload nginx
#
# CHECK CERTIFICATE EXPIRATION
# -----------------------------
# View certificate details:
#   openssl x509 -in /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem -noout -dates
#   sudo certbot certificates
#
# Renew if needed:
#   sudo certbot renew
#
# =============================================================================

set -e  # Exit on error

echo "======================================"
echo "SSL Certificate Setup (Let's Encrypt)"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo"
    echo "Usage: sudo ./setup-ssl.sh [domain]"
    exit 1
fi

# Prompt for domain if not provided
if [ -z "$1" ]; then
    echo "Enter domain name (e.g., example.com):"
    read -r DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "❌ Error: Domain name required"
        exit 1
    fi
else
    DOMAIN=$1
fi

echo "📋 Configuration:"
echo "   Domain: $DOMAIN"
echo ""

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing Certbot..."
    apt update
    apt install -y certbot python3-certbot-nginx
    echo "✓ Certbot installed"
fi

# Check if nginx is installed and running
if ! command -v nginx &> /dev/null; then
    echo "❌ Error: Nginx is not installed"
    echo "Please run the main deployment script first: sudo ./deploy.sh"
    exit 1
fi

if ! systemctl is-active --quiet nginx; then
    echo "⚠️  Nginx is not running. Starting nginx..."
    systemctl start nginx
fi

echo ""
echo "🔍 Checking DNS configuration..."
if ! dig +short "$DOMAIN" > /dev/null 2>&1 && ! nslookup "$DOMAIN" > /dev/null 2>&1; then
    echo "⚠️  Warning: Unable to verify DNS. Make sure $DOMAIN points to this server."
    echo "   Continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Cancelled. Please configure DNS first."
        exit 1
    fi
fi

echo ""
echo "🔒 Obtaining SSL certificate from Let's Encrypt..."
echo ""
echo "This will:"
echo "1. Verify domain ownership"
echo "2. Issue SSL certificate"
echo "3. Configure nginx for HTTPS"
echo "4. Set up automatic renewal"
echo ""

# Ensure ssl_dhparam is properly configured before running certbot
echo "🔧 Preparing SSL configuration..."

# Clean up any duplicate ssl_dhparam directives
if [ -f "/etc/letsencrypt/options-ssl-nginx.conf" ]; then
    sed -i '/ssl_dhparam/d' /etc/letsencrypt/options-ssl-nginx.conf
    echo "ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;" >> /etc/letsencrypt/options-ssl-nginx.conf
fi

# Run certbot - it will prompt for email interactively
certbot certonly --nginx \
    -d "$DOMAIN" \
    --agree-tos

CERTBOT_EXIT=$?

if [ $CERTBOT_EXIT -eq 0 ]; then
    echo ""
    echo "🔧 Manually configuring nginx for SSL..."

    # Backup current nginx config
    cp /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-available/${APP_NAME}.pre-ssl

    # Get the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    # Use the add-ssl-config.sh script
    if [ -f "$SCRIPT_DIR/add-ssl-config.sh" ]; then
        APP_NAME=${APP_NAME} bash "$SCRIPT_DIR/add-ssl-config.sh"
    elif [ -f "/home/ubuntu/${APP_NAME}/deployment/scripts/add-ssl-config.sh" ]; then
        APP_NAME=${APP_NAME} bash "/home/ubuntu/${APP_NAME}/deployment/scripts/add-ssl-config.sh"
    else
        echo "⚠️  Warning: SSL config script not found. Please run:"
        echo "   sudo APP_NAME=${APP_NAME} $SCRIPT_DIR/add-ssl-config.sh"
    fi

    # Ensure sites-enabled is a symlink, not a regular file
    if [ -f "/etc/nginx/sites-enabled/${APP_NAME}" ] && [ ! -L "/etc/nginx/sites-enabled/${APP_NAME}" ]; then
        echo "🔧 Fixing sites-enabled symlink..."
        rm /etc/nginx/sites-enabled/${APP_NAME}
        ln -s /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/${APP_NAME}
    fi

    # Remove default nginx config if it exists
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        echo "🔧 Removing default nginx config..."
        rm /etc/nginx/sites-enabled/default
    fi

    # Test and reload nginx
    nginx -t && systemctl restart nginx
    echo ""
    echo "======================================"
    echo "✅ SSL Certificate Installed!"
    echo "======================================"
    echo ""
    echo "Certificate details:"
    certbot certificates -d "$DOMAIN"
    echo ""
    echo "Your site is now accessible at: https://$DOMAIN"
    echo ""
    echo "Auto-renewal:"
    echo "- Certificates auto-renew via systemd timer"
    echo "- Check status: sudo systemctl status certbot.timer"
    echo "- Test renewal: sudo certbot renew --dry-run"
    echo ""
    echo "Important URLs for eBay:"
    echo "- Deletion endpoint: https://$DOMAIN/api/ebay/marketplace-account-deletion"
    echo "- OAuth callback: https://$DOMAIN/ebay/callback"
    echo ""
else
    echo ""
    echo "======================================"
    echo "❌ SSL Setup Failed"
    echo "======================================"
    echo ""
    echo "Common issues:"
    echo "1. Domain doesn't point to this server"
    echo "   - Check DNS: dig $DOMAIN"
    echo "   - Verify A record points to: $(curl -s ifconfig.me)"
    echo ""
    echo "2. Port 80 not accessible"
    echo "   - Check Lightsail networking tab"
    echo "   - Ensure HTTP (80) is allowed"
    echo ""
    echo "3. Nginx configuration error"
    echo "   - Test config: sudo nginx -t"
    echo "   - Check logs: sudo tail /var/log/nginx/error.log"
    echo ""
    exit 1
fi

# Verify HTTPS is working
echo "🔍 Verifying HTTPS configuration..."
sleep 2
if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200\|301\|302"; then
    echo "✓ HTTPS is working correctly"
else
    echo "⚠️  Warning: HTTPS verification returned unexpected status"
    echo "   Please manually verify: curl -I https://$DOMAIN"
fi

echo ""
echo "Next steps:"
echo "1. Test your endpoints:"
echo "   curl https://$DOMAIN/api/ebay/marketplace-account-deletion"
echo ""
echo "2. Update eBay Developer Portal with HTTPS URLs"
echo "3. Test the application: https://$DOMAIN"
echo ""
