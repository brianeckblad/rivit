#!/bin/bash
# Manually add SSL configuration to nginx
# NOTE: Update the DOMAIN variable below if your domain is different
# This script is used after initial setup to enable HTTPS

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the app name getter function
source "$SCRIPT_DIR/lib/get_app_name.sh"

# Get app name from config (or use environment variable override)
if [ -z "$APP_NAME" ]; then
    APP_NAME=$(get_app_name) || exit 1
fi

DOMAIN="your-domain.com"  # UPDATE THIS to your actual domain
NGINX_CONFIG="/etc/nginx/sites-available/${APP_NAME}"

echo "Adding SSL configuration for: $APP_NAME"
echo "Domain: $DOMAIN"

echo "Adding SSL server block to nginx config..."

# Add SSL server block at the end of the file
sudo tee -a "$NGINX_CONFIG" > /dev/null <<EOF

# HTTPS server block
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;

    # SSL stapling
    ssl_trusted_certificate /etc/letsencrypt/live/${DOMAIN}/chain.pem;
    ssl_stapling on;
    ssl_stapling_verify on;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Hide nginx version
    server_tokens off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    # Content Security Policy
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; style-src-elem 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' data: https://fonts.gstatic.com; connect-src 'self' https://*.amazonaws.com https://*.ebayimg.com; manifest-src 'self';" always;

    # Increase client body size for image uploads (50MB)
    client_max_body_size 50M;

    # Timeout settings for large uploads
    client_body_timeout 300s;
    proxy_read_timeout 300s;

    # Access and error logs
    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log /var/log/nginx/${APP_NAME}_error.log;

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to backup files
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Static files
    location /static/ {
        alias /home/ubuntu/${APP_NAME}/app/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # WAF-style path whitelist
    location ~ ^/(admin|phpmyadmin|wp-admin|wp-login|config|\.well-known|\.aws|\.git|\.env|backup|db|database|sql|shell|cmd|eval) {
        deny all;
        access_log off;
        log_not_found off;
        return 444;
    }

    # Authentication routes
    location ~ ^/(login|logout)$ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Main application pages
    location ~ ^/(add|browse|download(/ebay)?|price-lookup|account|trash)$ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # eBay Marketplace Account Deletion endpoint (public - required by eBay)
    location = /api/ebay/marketplace-account-deletion {
        allow all;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # API routes
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Root path
    location = / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Deny all other paths
    location / {
        deny all;
        access_log off;
        return 444;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name ${DOMAIN};

    # Allow Let's Encrypt certificate renewals
    location ^~ /.well-known/acme-challenge/ {
        allow all;
        root /var/www/html;
    }

    location / {
        if (\$host = ${DOMAIN}) {
            return 301 https://\$host\$request_uri;
        }
        return 404;
    }
}
EOF

echo "Testing nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "Reloading nginx..."
    sudo systemctl reload nginx
    echo "✅ SSL configuration added successfully!"
    echo ""
    echo "Testing HTTPS..."
    sleep 2
    curl -I https://${DOMAIN}
else
    echo "❌ Nginx configuration test failed!"
    exit 1
fi
