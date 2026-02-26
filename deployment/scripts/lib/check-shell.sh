#!/bin/bash
# Shell compatibility detection utility
# Source this file to check if running in a supported shell
# Supports: bash, ksh
# Exits with warning if unsupported shell is detected

check_shell_compatibility() {
    # Detect shell
    local current_shell
    current_shell=$(ps -p $$ -o comm= 2>/dev/null | tr -d '-')

    # Also check SHELL environment variable as fallback
    if [[ -z "$current_shell" ]]; then
        current_shell=$(basename "$SHELL" 2>/dev/null)
    fi

    # Check if shell is supported
    case "$current_shell" in
        bash|ksh)
            return 0  # Supported shell
            ;;
        *)
            # Unsupported shell
            echo "⚠️  WARNING: Unsupported shell detected!" >&2
            echo "   Current shell: $current_shell" >&2
            echo "   Supported shells: bash, ksh" >&2
            echo "" >&2
            echo "   This script requires bash or ksh to run properly." >&2
            echo "   Please run with: bash $0 or ksh $0" >&2
            echo "" >&2
            return 1
            ;;
    esac
}

# If this script is sourced (to use the function), don't exit
# If it's executed directly, check and exit
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_shell_compatibility
    exit $?
fi

