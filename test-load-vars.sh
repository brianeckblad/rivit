#!/bin/bash
# Test script to demonstrate load-vars.sh fix

cd "$(dirname "$0")/deployment" || exit 1

echo "=== Testing load-vars.sh Fix ==="
echo ""
echo "Before loading variables:"
echo "app_name value: '$app_name'"
echo ""

echo "Loading variables..."
source scripts/load-vars.sh
echo ""

echo "After loading variables:"
echo "app_name: '$app_name'"
echo "app_display_name: '$app_display_name'"
echo "aws_region: '$aws_region'"
echo "admin_user: '$admin_user'"
echo "server_name: '$server_name'"
echo ""

echo "=== Test Complete ==="

