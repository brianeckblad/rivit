#!/bin/bash
# Vault password script for Ansible
# Reads password from ~/.vault_pass file
# If file doesn't exist, prompts user to enter password
# This allows ansible.cfg to reference it without tilde expansion issues

VAULT_PASS_FILE="$HOME/.vault_pass"

if [ -f "$VAULT_PASS_FILE" ]; then
    # File exists - read password from it
    cat "$VAULT_PASS_FILE"
else
    # File doesn't exist - prompt user for password
    # Use /dev/tty to ensure we can read from terminal even if stdin is redirected
    read -s -p "Vault password: " VAULT_PASSWORD < /dev/tty
    echo "$VAULT_PASSWORD"
fi


