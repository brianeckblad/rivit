# Agent Operational Guidelines

**Instructions for AI agents working on this project**

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

### Rule 4: If dquote> Appears

If you see `dquote>` in console output:

```bash
# What it means: Quote escaping failed, command not executed
# Don't try again with same message

# Instead: Use file method
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

**Last Updated:** February 17, 2026
**Status:** Operational Guidelines Established

