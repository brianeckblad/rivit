#!/bin/bash
# Diagnostic script to test load-vars.sh functionality

cd /Users/brian/Development/rampe/deployment

echo "=== DIAGNOSTIC TEST FOR load-vars.sh ==="
echo ""

echo "1. Testing file existence:"
echo "  all.yml exists: $([ -f group_vars/all.yml ] && echo YES || echo NO)"
echo "  vault.yml exists: $([ -f group_vars/vault.yml ] && echo YES || echo NO)"
echo ""

echo "2. Testing parse function directly:"
bash << 'PARSE_TEST'
parse_yaml_simple() {
    local file=$1
    echo "  Parsing: $file"
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ "$line" =~ ^([a-z_]+):[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            if [[ "$value" == *"{{"* ]] || [[ "$value" == *"}}"* ]] || \
               [[ "$value" == "["* ]] || [[ "$value" == "{"* ]]; then
                continue
            fi

            value="${value%% #*}"
            value="${value//\"/}"
            value="${value//\'/}"
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            [[ -z "$value" ]] && continue

            echo "    $key=$value"
            count=$((count+1))
            [[ $count -gt 10 ]] && break
        fi
    done < "$file"
    echo "  Total parsed: $count"
}

parse_yaml_simple "group_vars/all.yml"
PARSE_TEST
echo ""

echo "3. Testing with sourced script:"
source scripts/load-vars.sh 2>&1 | grep -A 10 "Available variables"
echo ""

echo "4. Checking if variables are actually exported:"
source scripts/load-vars.sh >/dev/null 2>&1
echo "  app_name=[$app_name]"
echo "  admin_user=[$admin_user]"
echo "  server_name=[$server_name]"
echo ""

echo "5. Checking via env command:"
source scripts/load-vars.sh >/dev/null 2>&1
env | grep -E "^app_name|^admin_user|^server_name" | sort


