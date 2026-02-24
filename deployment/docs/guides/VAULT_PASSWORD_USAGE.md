# Running Playbooks with Encrypted Vault Variables

## Overview

All playbooks in this deployment system load variables from:
- `group_vars/all.yml` - Regular configuration (not encrypted)
- `group_vars/vault.yml` - Sensitive data (encrypted with Ansible Vault)

When vault.yml is encrypted, you must provide the vault password when running playbooks.

## How Ansible Handles Vault Decryption

When you run a playbook with `vars_files: ../group_vars/vault.yml`:

1. **Ansible checks if vault.yml is encrypted**
   - Looks for `$ANSIBLE_VAULT;1.1;AES256` header
   - If present, the file is encrypted

2. **Ansible prompts for/reads the vault password**
   - From `--vault-password-file ~/.vault_pass`, OR
   - From `--ask-vault-pass` interactive prompt, OR
   - From `$ANSIBLE_VAULT_PASSWORD` environment variable

3. **Ansible decrypts the file in memory**
   - Never creates unencrypted copies on disk
   - Variables are available to the playbook
   - Remains encrypted in the repository

4. **Playbook runs with decrypted variables**
   - All vault variables are accessible
   - Like any other variable

## Running Playbooks

### Recommended: Using ~/.vault_pass file

Create the vault password file (one-time setup):

```bash
# Create password file with your vault password
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

Then run any playbook with:

```bash
ansible-playbook playbooks/setup-waf.yml --vault-password-file ~/.vault_pass
```

### Alternative: Interactive password prompt

Run playbook with:

```bash
ansible-playbook playbooks/setup-waf.yml --ask-vault-pass
```

You'll be prompted to enter the vault password before the playbook runs.

### Alternative: Environment variable

```bash
export ANSIBLE_VAULT_PASSWORD="your-vault-password"
ansible-playbook playbooks/setup-waf.yml
```

## All Playbooks Requiring Vault

These playbooks need vault.yml decryption:

| Playbook | Purpose |
|----------|---------|
| `create-s3-bucket.yml` | Create S3 storage |
| `provision-infrastructure.yml` | Infrastructure setup |
| `setup-ssl.yml` | SSL certificate setup |
| `setup-monitoring.yml` | CloudWatch monitoring |
| `setup-secrets-manager.yml` | AWS Secrets Manager |
| `security-hardening.yml` | Security hardening |
| `setup-cloudfront.yml` | CloudFront CDN |
| `setup-waf.yml` | AWS WAF configuration |
| `secret-promote.yml` | Secret promotion |
| `secret-rotate.yml` | Secret rotation |
| `secret-sync.yml` | Vault to AWS sync |

All require the vault password to run successfully.

## Checking If Vault Is Encrypted

```bash
head -1 deployment/group_vars/vault.yml
```

**Encrypted (contains):**
```
$ANSIBLE_VAULT;1.1;AES256
```

**Unencrypted (contains):**
```
---
```

## Troubleshooting

### Error: "Vault password not provided"

```
ERROR! Vault password not provided
```

**Solution:** Add `--vault-password-file ~/.vault_pass` or `--ask-vault-pass` to your command.

### Error: "Vault password too short or incorrect"

```
fatal: [localhost]: FAILED! => {"msg": "Decryption failed"}
```

**Solution:** Check that the vault password is correct. Re-run with correct password.

### How to decrypt vault manually

To view decrypted vault.yml (read-only):

```bash
ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass
```

To decrypt vault for editing:

```bash
ansible-vault edit group_vars/vault.yml --vault-password-file ~/.vault_pass
```

## Security Best Practices

1. **Never commit unencrypted vault.yml**
   - Always keep it encrypted in git
   - `.gitignore` protects `vault.yml.decrypted.*`

2. **Protect ~/.vault_pass**
   ```bash
   chmod 600 ~/.vault_pass
   ```
   - Only you can read it
   - Prevents others from accessing vault password

3. **Never share vault password in code/logs**
   - Store in `~/.vault_pass` only
   - Use `--ask-vault-pass` when sharing system access

4. **Rotate vault password periodically**
   ```bash
   ansible-vault rekey group_vars/vault.yml --vault-password-file ~/.vault_pass
   ```

## Summary

The key point: **Ansible handles vault decryption automatically**

- You just need to provide the password
- Use `--vault-password-file ~/.vault_pass` OR `--ask-vault-pass`
- Variables are then available in playbooks
- No manual decryption needed


