# Copilot Instructions

**These instructions are automatically loaded for every Copilot session in this project.**

For full details see [AGENTS.md](../AGENTS.md) in the project root.

---

## Shell Command Safety - CRITICAL

### Never Output Jinja2 Braces Through the Terminal

The zsh shell interprets `{{ }}` as glob patterns. Commands that output Jinja2 content will hang or produce empty output.

```bash
# BAD - causes empty output or hangs
cat file_with_jinja.yml
grep "pattern" file_with_jinja.yml
head file_with_jinja.yml

# GOOD - use the read_file / grep_search tools instead (they bypass the shell)
# GOOD - if terminal is required, use Python:
python3 -c "print(open('file.yml').read()[:500])"
```

### Never Use Unquoted Heredocs with Dynamic Content

```bash
# BAD - shell interprets {{ }} and $vars, causes heredoc> hang
cat > file.yml << EOF
name: "{{ app_name }}"
EOF

# GOOD - single-quote the delimiter
cat > file.yml << 'EOF'
name: "{{ app_name }}"
EOF

# BEST - use Python or the insert_edit_into_file tool to write files
```

### Prefer Non-Terminal Tools

| Task | Use This | Not This |
|------|----------|----------|
| Read a file | `read_file` tool | `cat` / `head` / `tail` in terminal |
| Search in file | `grep_search` tool | `grep` in terminal |
| Write / edit a file | `insert_edit_into_file` or `replace_string_in_file` tool | `cat > file << EOF` in terminal |
| Verify edits applied | `read_file` tool | `cat file` in terminal |

### If Terminal Hangs (no output, or dquote> / heredoc> / quote>)

1. **Do NOT keep waiting** - it will not recover
2. **Run a new terminal command** - the tool starts a fresh session
3. **Switch to a non-terminal tool** to accomplish the task
4. **Re-validate** using `read_file` after recovering

### Ansible Playbooks

- Run with `isBackground: true` and retrieve output with `get_terminal_output` for long-running playbooks
- Pipe short playbook runs through `2>&1` to capture all output

---

## Git Commit Rules

```bash
# ALWAYS - simple messages, no internal quotes
git commit -m "docs: add deployment guide"
git commit -m "fix: correct IAM role permissions"

# NEVER - nested quotes cause dquote> hangs
git commit -m "docs: add 'comprehensive' guide"

# FOR COMPLEX MESSAGES - use file method
cat > /tmp/msg.txt << 'EOF'
feat: multi-line commit message

- Detail one
- Detail two
EOF
git commit -F /tmp/msg.txt && rm /tmp/msg.txt
```

---

## Documentation Standards

All docs in `deployment/docs/` follow a consistent vendor-guide style. See [AGENTS.md](../AGENTS.md) for the full rules.

**Key rules:**

- Guides use `# Chapter N: Title` with a one-line subtitle — no version/date metadata
- One prerequisite note per file, not a re-verification checklist
- End guides with a single `## Next step` link — no repeated "next step" sections
- No emojis in headings, no analogies, no marketing bullets
- Cross-reference by chapter number: "See [Chapter 5: Operations](OPERATIONS.md)"
- Chapter numbers (1–13) are tracked in `deployment/docs/README.md`

---

## Project Context

- **Stack:** Python / Flask application with Ansible deployment to AWS EC2
- **Shell:** zsh on macOS
- **Deployment config:** `deployment/` directory with Ansible playbooks, group_vars, vault
- **Ansible variables:** Loaded from `deployment/group_vars/all.yml` and encrypted `vault.yml`
- **Vault secrets:** Access with `ansible-vault view group_vars/vault.yml --vault-password-file ~/.vault_pass`
- **S3 bucket name:** Comes from `vault_s3_bucket_name` in vault (not derived from `app_name`)

