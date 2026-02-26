#!/bin/bash
#
# Get App Name from Configuration
# Supported shells: bash, ksh
# This script reads app_name from group_vars/all.yml
# Used by other scripts to ensure consistency
#

# Shell compatibility check
current_shell=$(ps -p $$ -o comm= 2>/dev/null | tr -d '-')
if [[ -z "$current_shell" ]]; then
    current_shell=$(basename "$SHELL" 2>/dev/null)
fi
case "$current_shell" in
    bash|ksh)
        ;; # Supported shell
    *)
        echo "⚠️  WARNING: Unsupported shell detected!" >&2
        echo "   Current shell: $current_shell" >&2
        echo "   Supported shells: bash, ksh" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

# Find the deployment directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$DEPLOYMENT_DIR/group_vars/all.yml"

# Function to extract app_name from YAML config
get_app_name() {
    if [ -f "$CONFIG_FILE" ]; then
        # Try to extract app_name from YAML (handles various formats)
        APP_NAME=$(grep -E "^app_name:" "$CONFIG_FILE" | head -1 | sed 's/^app_name:[[:space:]]*//' | sed 's/#.*//' | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")

        # Validate we got something
        if [ -n "$APP_NAME" ] && [ "$APP_NAME" != "CHANGEME" ]; then
            echo "$APP_NAME"
            return 0
        else
            echo "ERROR: app_name not set in $CONFIG_FILE (currently: $APP_NAME)" >&2
            echo "Edit $CONFIG_FILE and set app_name to your application name" >&2
            return 1
        fi
    else
        echo "ERROR: Config file not found: $CONFIG_FILE" >&2
        return 1
    fi
}

# If script is sourced, just define the function
# If script is executed directly, call the function
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    get_app_name
fi

