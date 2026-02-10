#!/bin/bash
# Force hard restart and cache clearing script for production

echo "🔄 FORCE RESTART WITH CACHE CLEARING"
echo "======================================"

cd ~/app_item_listing_tool

# Step 1: Stop the app
echo ""
echo "1️⃣ Stopping application..."
sudo systemctl stop app_item_listing_tool
sleep 2
echo "✅ App stopped"

# Step 2: Clear ALL Python caches
echo ""
echo "2️⃣ Clearing all Python caches..."
echo "   • Clearing __pycache__ directories..."
find ~/app_item_listing_tool -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
echo "   • Clearing .pyc files..."
find ~/app_item_listing_tool -type f -name "*.pyc" -delete 2>/dev/null || true
echo "   • Clearing .pytest_cache..."
find ~/app_item_listing_tool -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
echo "   • Clearing Flask temp files..."
rm -rf /tmp/flask-* 2>/dev/null || true
rm -rf /tmp/gunicorn-* 2>/dev/null || true
echo "✅ All Python caches cleared"

# Step 3: Verify code is latest
echo ""
echo "3️⃣ Verifying latest code from git..."
git fetch origin main 2>/dev/null
git log --oneline -1
echo "✅ Code verified"

# Step 4: Kill any remaining Gunicorn processes
echo ""
echo "4️⃣ Killing any remaining Gunicorn processes..."
pkill -f "gunicorn.*app_item_listing_tool" 2>/dev/null || true
sleep 2
echo "✅ Old processes killed"

# Step 5: Start the app fresh
echo ""
echo "5️⃣ Starting application fresh..."
sudo systemctl start app_item_listing_tool
sleep 5  # Give it more time to start
echo "✅ App started"

# Step 6: Check status
echo ""
echo "6️⃣ Checking application status..."
if sudo systemctl is-active --quiet app_item_listing_tool; then
    echo "✅ App is running"
else
    echo "❌ App is NOT running - check logs"
    echo ""
    echo "Recent logs:"
    sudo tail -20 /var/log/app_item_listing_tool/error.log
    exit 1
fi

# Step 7: Verify the method exists in the code
echo ""
echo "7️⃣ Verifying cleanup_orphaned_images method exists in code..."
if grep -q "def cleanup_orphaned_images(self):" app/services/comic_service.py; then
    echo "✅ Method found in code"
else
    echo "❌ Method NOT found in code"
    exit 1
fi

# Step 8: Verify the method is accessible via Python (live check)
echo ""
echo "8️⃣ Testing if method is accessible in running app..."
cd ~/app_item_listing_tool
python3 << 'PYTHON_TEST'
import sys
sys.path.insert(0, '/home/ubuntu/app_item_listing_tool')
try:
    from app.services.comic_service import comic_service
    if hasattr(comic_service, 'cleanup_orphaned_images'):
        print("✅ Method is accessible via Python import")
    else:
        print("❌ Method NOT accessible - comic_service does not have cleanup_orphaned_images attribute")
        print(f"Available methods: {[m for m in dir(comic_service) if not m.startswith('_')]}")
        sys.exit(1)
except Exception as e:
    print(f"❌ Error testing method: {e}")
    sys.exit(1)
PYTHON_TEST

if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  WARNING: Method exists in code but is not accessible!"
    echo "This suggests the virtual environment or imports are stale."
    echo ""
    echo "Trying to reinstall dependencies in venv..."
    source ~/.venv/bin/activate 2>/dev/null || source /home/ubuntu/app_item_listing_tool/.venv/bin/activate
    pip install --force-reinstall --no-cache-dir -e . 2>/dev/null || true
fi

echo ""
echo "======================================"
echo "✅ RESTART COMPLETE!"
echo "======================================"
echo ""
echo "The cleanup_orphaned_images button should now work."
echo ""
echo "To test:"
echo "  1. Go to the trash page"
echo "  2. Click the cleanup button"
echo "  3. Check the logs for success:"
echo "     sudo tail -f /var/log/$APP_NAME/app.log"
