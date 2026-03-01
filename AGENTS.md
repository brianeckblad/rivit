# Agent Operational Guidelines

**Instructions for AI agents working on this project**

> **Auto-loaded rules:** The critical rules from this file are also in
> [`.github/copilot-instructions.md`](.github/copilot-instructions.md),
> which GitHub Copilot reads automatically at the start of every session.

---

## Shell Command Safety - CRITICAL

### Problem
Commands containing `{{ }}` (Jinja2), nested quotes, or heredocs cause the terminal to hang
waiting for input (`dquote>`, `heredoc>`, `quote>`). The agent cannot type interactively,
so the session freezes and the user must Ctrl-C to recover.

### Rule: Never Output Jinja2 Braces Through the Terminal

The zsh shell interprets `{{ }}` as glob patterns. Any command that outputs Jinja2 content
through the shell will hang or produce empty output.

```bash
# BAD - shell interprets {{ }} braces
cat file_with_jinja.yml
grep "pattern" file_with_jinja.yml
echo "{{ app_name }}"

# GOOD - use read_file / grep_search tools instead (they bypass the shell)

# GOOD - if terminal is required, use Python
python3 -c "print(open('file.yml').read()[:500])"
```

### Rule: Never Use Unquoted Heredocs with Dynamic Content

```bash
# BAD - heredoc interprets variables and braces, causes heredoc> hang
cat > file.yml << EOF
name: "{{ app_name }}"
EOF

# GOOD - single-quote the delimiter to prevent interpretation
cat > file.yml << 'EOF'
name: "{{ app_name }}"
EOF

# BEST - use Python or the insert_edit_into_file tool
```

### Rule: Prefer Non-Terminal Tools

| Task | Use This | Not This |
|------|----------|----------|
| Read a file | `read_file` tool | `cat` / `head` / `tail` in terminal |
| Search in file | `grep_search` tool | `grep` in terminal |
| Write / edit a file | `insert_edit_into_file` or `replace_string_in_file` tool | `cat > file << EOF` in terminal |
| Verify edits applied | `read_file` tool | `cat file` in terminal |

**When you must use the terminal** (running commands, playbooks, aws cli):
- Pipe through `| cat` to avoid pagers
- Use `2>&1` to capture stderr
- Run long commands with `isBackground: true`

### Rule: If Terminal Hangs (dquote>, heredoc>, quote>)

If the terminal produces no output or you suspect it is stuck:

1. **Do NOT keep waiting** - the session will not recover on its own
2. **Run a new terminal command** - the tool starts a fresh session
3. **Switch to a non-terminal tool** (read_file, grep_search, insert_edit_into_file)
4. **Re-validate** using the appropriate tool after recovering

---

## Git Commit Workflow - CRITICAL

### Problem Solved
The project experienced recurring `dquote>` console errors when making git commits. This has been analyzed and resolved.

**See detailed explanation:** [WHY_DQUOTE_ERROR_AND_FIX.md](WHY_DQUOTE_ERROR_AND_FIX.md)

### Rule 1: Keep Git Commit Messages Simple (Primary Method)

**ALWAYS use simple commit messages without internal quotes:**

```bash
# GOOD - Simple messages work perfectly
git commit -m "docs: add deployment guide"
git commit -m "fix: correct CloudWatch permissions"
git commit -m "feat: add validation script"
git commit -m "docs: update MAINTENANCE_CHECKLIST for quarterly reviews"

# BAD - These cause dquote> errors
git commit -m "docs: add 'comprehensive' guide"
git commit -m "fix: update 'CloudWatch' 'permissions'"
git commit -m "docs: update 'guide' with 'new' features"
```

**Why?**
- No quote escaping needed
- Shell interprets message correctly
- Console shows clean output
- Commits go through immediately

### Rule 2: For Complex Messages, Use File Method (Backup Method)

**If you need multi-line or complex messages, use commit message file:**

```bash
# Create message file with complex content
cat > /tmp/commit_msg.txt << 'EOF'
docs: comprehensive documentation update

Added new guides:
- UPDATING_APPLICATION.md: Deploy code changes
- SECURITY_HARDENING.md: Secure your server
- WAF_CONFIGURATION.md: Web Application Firewall
- CLOUDFRONT_CDN.md: Global CDN

All links verified with 100% accuracy.
EOF

# Commit using file (avoids ALL quote issues)
git commit -F /tmp/commit_msg.txt

# Clean up
rm /tmp/commit_msg.txt
```

**Why this method?**
- No shell interpretation of file contents
- No quotes to escape
- Multi-line messages work perfectly
- Special characters handled correctly
- Always works, never fails

### Rule 3: NEVER Nest Quotes in -m Parameter

```bash
# NEVER DO THIS
git commit -m "docs: update 'guide' to 'version 2'"
git commit -m "docs: add 'comprehensive' setup with 'best' practices"
git commit -m "fix: handle 'special' 'characters' correctly"

# DO THIS INSTEAD
git commit -m "docs: update guide to version 2"
git commit -m "docs: add comprehensive setup with best practices"
git commit -m "fix: handle special characters correctly"

# OR use file method if you really need quotes
```

### Rule 4: If dquote> or heredoc> Appears

If you see `dquote>`, `heredoc>`, or `quote>` in console output:

1. **Stop immediately** - do not send more text
2. **Run a new terminal command** - the tool starts a fresh session
3. **Use the file method** for the failed operation
4. **See also:** [Shell Command Safety](#shell-command-safety---critical) for prevention rules

```bash
# Recovery: Use file method for git
cat > /tmp/msg.txt << 'EOF'
Your message here without worrying about quotes
EOF
git commit -F /tmp/msg.txt && rm /tmp/msg.txt
```

---

## Workflow Checklist

Before committing, verify:

- [ ] Using simple message format (no internal quotes)
  - OR using file method for complex messages
- [ ] Message is descriptive (tells what changed, not how)
- [ ] No 'quotes' inside the -m "message" parameter
- [ ] Related files staged with git add
- [ ] Running from project root directory

---

## Example Good Commits

```bash
# Fix
git commit -m "fix: correct CloudWatch IAM policy name"

# Docs
git commit -m "docs: add comprehensive deployment guide"

# Feature
git commit -m "feat: add automated validation script"

# Refactor
git commit -m "refactor: simplify git commit handling"

# Multiple changes (keep simple)
git commit -m "docs: add guides and maintenance system"
```

---

## Example Bad Commits (Will Cause dquote>)

```bash
# Don't use these
git commit -m "docs: add 'guide' with 'features'"
git commit -m "fix: correct 'CloudWatch' 'permissions'"
git commit -m "feat: implement 'validation' and 'testing'"

# These will show dquote> error and fail
```

---

## Git Command Best Practices

### For All Git Operations:

1. **Use simple, descriptive messages**
   - First line: One-line summary (50 chars max)
   - Then blank line
   - Then details if needed

2. **Prefer file method for complex messages**
   ```bash
   cat > /tmp/msg.txt << 'EOF'
   Summary line here

   Details:
   - Item 1
   - Item 2
   EOF
   git commit -F /tmp/msg.txt && rm /tmp/msg.txt
   ```

3. **Always verify before committing**
   ```bash
   git status  # See what's staged
   git diff --staged  # See exact changes
   ```

4. **Push immediately after committing**
   ```bash
   git push origin main
   ```

---

## Reference Documents

For detailed information about the git commit quote issue:

- **WHY_DQUOTE_ERROR_AND_FIX.md** - Complete explanation
- **GIT_COMMIT_QUOTE_FIX.md** - Solutions and best practices
- **deployment/scripts/git-commit-safe.sh** - Helper script

---

## Documentation Standards

All documentation in `deployment/docs/` follows a consistent style modeled after
professional vendor guides (Cisco, HashiCorp, AWS). Apply these rules when creating
or editing any `.md` file in the project.

### File Structure

**Guides** (procedural, step-by-step):

```markdown
# Chapter N: Title

One-line description of what this chapter covers.

---

## Section Name

Content...

---

## Next step

Continue to [Chapter N+1: Title](NEXT_FILE.md).

## See also

- [Chapter X: Title](FILE.md) — brief reason
- [Reference: Title](../reference/FILE.md) — brief reason
```

**Reference docs** (descriptive, not procedural):

```markdown
# Title Reference

One-line description.

---

## Section Name

Content...
```

### Rules

| Rule | Do | Do Not |
|------|----|--------|
| Title format (guides) | `# Chapter 6: Monitoring` | `# CloudWatch Monitoring Guide` |
| Title format (reference) | `# Architecture Reference` | `# Architecture Reference Guide v5.0` |
| Subtitle | One plain sentence | Bold text, version numbers, dates, status badges |
| Ending (guides) | Single `## Next step` link, optional `## See also` (2–3 links max) | Multiple "next step" sections, decision tables, "pick one" blocks |
| Prerequisite reference | `> Prerequisite: Complete [Chapter 1](PREREQUISITES.md).` | 15-line checklist re-verifying the previous chapter |
| Cross-references | `See [Chapter 5: Operations](OPERATIONS.md).` | `→ **[OPERATIONS.md](OPERATIONS.md)** — Full guide!` |
| Tone | Direct, declarative prose | Emojis in headings, exclamation marks, "Think of it as…" analogies |
| Metadata | None — use Git history | `**Version:** 5.0`, `**Date:** Feb 2026`, `**Status:** Production-Ready` |
| Variable placeholders | Use `{app_name}` inline without explanation | Multi-line note explaining what `{app_name}` means (stated once in Ch. 1) |
| Emoji | Allowed in verification output (`✓`) and warnings (`⚠️`) | Not in headings, not in bullet lists as decoration (`🚀`, `📋`, `🎉`) |

### Chapter Numbers

Guides are numbered 1–13. The table of contents is `deployment/docs/README.md`.
When adding a new guide, assign the next number and update the README.

| Chapter | File |
|---------|------|
| 1 | PREREQUISITES.md |
| 2 | QUICKSTART.md |
| 3 | MANUAL_DEPLOYMENT.md |
| 3b | AWS_CONSOLE_DEPLOYMENT.md |
| 4 | UPDATING_APPLICATION.md |
| 5 | OPERATIONS.md |
| 6 | MONITORING.md |
| 7 | SECRET_MANAGEMENT.md |
| 8 | SECURITY_HARDENING.md |
| 9 | MULTI_USER.md |
| 10 | CLOUDFRONT_CDN.md |
| 11 | WAF_CONFIGURATION.md |
| 12 | GIT_CONFIGURATION.md |
| 13 | DECOMMISSION.md |

### Writing Checklist

Before finalizing any documentation change:

- [ ] Title matches the `# Chapter N: Title` pattern (guides) or `# Title` (reference)
- [ ] No version, date, or status metadata in the header
- [ ] No repeated prerequisite checks from the previous chapter
- [ ] File ends with a single `## Next step` (guides) or nothing (reference)
- [ ] No emojis in section headings
- [ ] Cross-references use chapter numbers: "See Chapter 5" not "See OPERATIONS.md"
- [ ] `docs/README.md` table of contents is updated if a file was added or renamed

---

## Summary

| Aspect | Guideline |
|--------|-----------|
| Primary Method | Simple commit messages (no internal quotes) |
| Backup Method | File method for complex messages |
| Never Do | Nest quotes in -m parameter |
| If dquote> Appears | Use file method instead |
| Pattern | git commit -m "type: description" |
| Example | git commit -m "docs: add deployment guide" |

---

**Key Point:** Following Rule 1 (simple messages) and Rule 2 (file method for complex) will PREVENT all dquote> errors from happening again.

---

**Last Updated:** February 26, 2026
**Status:** Operational Guidelines Established

