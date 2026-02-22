#!/bin/bash
# Vault password script for Ansible
# Reads password from ~/.vault_pass file
# This allows ansible.cfg to reference it without tilde expansion issues

VAULT_PASS_FILE="$HOME/.vault_pass"

if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo "Error: Vault password file not found at $VAULT_PASS_FILE" >&2
    exit 1
fi

cat "$VAULT_PASS_FILE"

