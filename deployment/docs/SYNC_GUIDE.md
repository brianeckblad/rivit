# Keeping Playbooks and Documentation in Sync

**Procedures for maintaining alignment between code and documentation**

---

## The Problem

**Playbooks change, but documentation can get outdated.**

Examples:
- ❌ Playbook adds new task, docs don't mention it
- ❌ Variable name changes, docs still show old name
- ❌ Required parameter added, docs don't list it
- ❌ AWS resource changed, playbook updated but docs weren't
- ❌ Procedure simplified, docs still show complex steps

**Result:** Users follow outdated docs, things break, they get frustrated.

---

## The Solution

**Keep playbooks and docs in sync with a systematic process.**

---

## When a Playbook Changes

### Step 1: Identify the Change

When you modify a playbook, note:
- What changed?
- Why did it change?
- Does it affect users?
- Does documentation need updating?

### Step 2: Update Documentation

**Before committing playbook changes, update the docs:**

```bash
# 1. Identify which doc references this playbook
grep -r "playbook_name" deployment/docs/

# 2. Update the relevant docs
nano deployment/docs/guides/RELEVANT_GUIDE.md

# 3. Update PLAYBOOKS.md reference if needed
nano deployment/docs/reference/PLAYBOOKS.md

# 4. Commit both together
git add deployment/playbooks/playbook.yml
git add deployment/docs/guides/RELEVANT_GUIDE.md
git commit -m "feat: update playbook and documentation

Playbook: [description of change]
Documentation: [what was updated in docs]"
```

### Step 3: Update CHANGELOG

```bash
nano deployment/docs/CHANGELOG.md
# Add entry under current month explaining the change
```

---

## When Documentation Changes

### Step 1: Verify Playbook Still Works

Before publishing docs, test:
- Does the playbook mentioned still exist?
- Do commands still work?
- Are variable names correct?
- Do procedures still apply?

```bash
# Example: Test a procedure
cd deployment
ansible-playbook playbooks/update.yml --check
# (--check = dry run, doesn't actually deploy)

# Or test commands
ansible-playbook -i inventories playbooks/setup-monitoring.yml --list-tasks
# (Shows what tasks will run, verify they match docs)
```

### Step 2: Commit Documentation Changes

```bash
git add deployment/docs/guides/GUIDE_NAME.md
git commit -m "docs: update [guide name] for [reason]

- [specific change 1]
- [specific change 2]"
```

### Step 3: Update CHANGELOG

Add entry noting what was updated and why.

---

## Sync Checklist

**Before committing any changes, verify:**

### If Changing a Playbook:
- [ ] Playbook syntax is valid
  ```bash
  ansible-playbook deployment/playbooks/name.yml --syntax-check
  ```
- [ ] Documentation mentioning it is updated
- [ ] PLAYBOOKS.md reference still accurate
- [ ] CHANGELOG.md is updated
- [ ] Links to playbook still work
- [ ] Examples in docs still valid
- [ ] Time estimates still accurate

### If Changing Documentation:
- [ ] All commands still work
- [ ] All playbook names match actual files
- [ ] All links point to valid files
- [ ] Variable names match actual config
- [ ] Examples still run without errors
- [ ] Procedures still match actual steps
- [ ] Screenshots/UI matches current AWS Console
- [ ] Cost estimates still accurate
- [ ] Time estimates still realistic

---

## Common Changes & How to Handle Them

### Change 1: Playbook Adds New Task

**Scenario:** `setup-monitoring.yml` adds a new CloudWatch dashboard creation task

**Steps:**
1. Update playbook, test it
2. Update `MONITORING.md`:
   - Mention dashboard creation is now automatic
   - Remove manual steps if any
   - Add what users will see
3. Update `PLAYBOOKS.md`:
   - Update description: "Configure CloudWatch (logs and dashboards)"
4. Commit all together:
   ```bash
   git commit -m "feat: automate CloudWatch dashboard creation
   
   Playbook:
   - Added task to create default monitoring dashboard
   
   Documentation:
   - Updated MONITORING.md: dashboards now created automatically
   - Updated PLAYBOOKS.md description"
   ```

### Change 2: Variable Name Changes

**Scenario:** `app_name` becomes `application_name` in all.yml

**Steps:**
1. Update playbook variable references
2. Update configuration template: `all.yml.example`
3. Find and replace in ALL docs:
   ```bash
   grep -r "app_name" deployment/docs/
   sed -i 's/app_name/application_name/g' deployment/docs/guides/*.md
   sed -i 's/app_name/application_name/g' deployment/docs/reference/*.md
   ```
4. Update PLAYBOOKS.md examples
5. Commit with:
   ```bash
   git commit -m "refactor: rename app_name to application_name
   
   - Updated playbooks to use new variable name
   - Updated all.yml.example template
   - Updated all documentation references (20+ files)
   - Updated examples in guides"
   ```

### Change 3: AWS Service Changes

**Scenario:** AWS CloudFront pricing changes

**Steps:**
1. Update cost section in `CLOUDFRONT_CDN.md`
2. Update cost table in `deployment/README.md` if referenced
3. Update CHANGELOG
4. Commit:
   ```bash
   git commit -m "docs: update CloudFront pricing information
   
   - Updated cost estimates in CLOUDFRONT_CDN.md
   - Added note about new pricing structure
   - Updated cost comparison examples"
   ```

### Change 4: Procedure Simplified

**Scenario:** SSL renewal is now fully automatic, no manual steps needed

**Steps:**
1. Update `OPERATIONS.md`:
   - Remove manual renewal section
   - Add: "SSL renewal is automatic, no action needed"
   - Keep verification steps
2. Update `SECURITY_HARDENING.md` if mentioned
3. Commit:
   ```bash
   git commit -m "docs: update SSL renewal to reflect automation
   
   - Removed manual renewal steps (now automatic)
   - Kept verification procedures
   - Added note about when auto-renewal runs
   - Updated OPERATIONS.md"
   ```

---

## Validation Before Commit

### Quick Check (2 minutes)
```bash
# 1. Check for broken links
grep -r "\]\(.*\.md" deployment/docs/ | grep -v "http"

# 2. Check for outdated playbook names
grep -r "create-s3-bucket.yml" deployment/docs/
# Should find references in docs

# 3. Check syntax of code examples
# Read through bash code blocks, verify they look correct

# 4. Check variable naming
grep -r "{app_name}" deployment/docs/ | head -5
# Should see consistent variable usage
```

### Thorough Check (10 minutes)
```bash
# 1. Run validation script
cd deployment/docs
bash validate-docs.sh

# 2. Test actual commands
aws sts get-caller-identity
ansible --version

# 3. Test a playbook (dry run)
cd ..
ansible-playbook playbooks/setup-monitoring.yml --check

# 4. Manually review changed files
git diff deployment/docs/guides/CHANGED_GUIDE.md
```

---

## Preventing Sync Issues

### 1. Code Review Process

When reviewing pull requests with playbook changes:

```markdown
Checklist for reviewers:

- [ ] Playbook changes are sound
- [ ] Related docs have been updated
- [ ] PLAYBOOKS.md still accurate
- [ ] CHANGELOG.md has entry
- [ ] All links still work
- [ ] Commands in docs still valid
```

### 2. Pre-Commit Hook (Optional)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Check that playbooks match documentation

# If playbooks changed
if git diff --cached --name-only | grep -q "^deployment/playbooks/"; then
    echo "Playbooks changed - remember to update docs!"
    
    # Find which playbooks changed
    git diff --cached --name-only | grep "^deployment/playbooks/" | \
    while read playbook; do
        name=$(basename $playbook .yml)
        if ! grep -q "$name" deployment/docs/reference/PLAYBOOKS.md; then
            echo "WARNING: $name not in PLAYBOOKS.md reference!"
        fi
    done
fi

# If docs changed
if git diff --cached --name-only | grep -q "^deployment/docs/"; then
    echo "Documentation changed - verify it's accurate!"
    bash deployment/docs/validate-docs.sh
fi

exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

### 3. Periodic Sync Check

Run quarterly:
```bash
# Compare playbooks with docs
echo "=== Playbooks documented in PLAYBOOKS.md ==="
ls -1 deployment/playbooks/*.yml | xargs -n1 basename > /tmp/playbooks.txt
grep "^| \`" deployment/docs/reference/PLAYBOOKS.md | \
    sed "s/.*\`\(.*\)\.yml\`.*/\1/" > /tmp/documented.txt

echo "Documented:"
cat /tmp/documented.txt

echo ""
echo "Missing documentation:"
comm -23 <(sort /tmp/playbooks.txt) <(sort /tmp/documented.txt)
```

---

## Sync Decision Tree

**Use this to decide what needs updating:**

```
Did something change?
├─ YES: Playbook file
│  ├─ New playbook?
│  │  ├─ Add to PLAYBOOKS.md
│  │  ├─ Create guide if major feature
│  │  └─ Link from README
│  ├─ Modified playbook?
│  │  ├─ Update PLAYBOOKS.md description
│  │  ├─ Update relevant guide
│  │  └─ Check all examples still work
│  └─ Deleted playbook?
│     ├─ Remove from PLAYBOOKS.md
│     ├─ Update all guides mentioning it
│     └─ Update README if needed
│
├─ YES: Documentation file
│  ├─ Test all commands shown
│  ├─ Verify playbook names exist
│  ├─ Check variable names match
│  ├─ Verify links work
│  └─ Test procedures if possible
│
└─ NO: Just review for accuracy quarterly
```

---

## Integration with CI/CD

### GitHub Actions Check (Optional)

Could add automated checks:

```yaml
name: Docs-Playbooks Sync Check

on: [pull_request]

jobs:
  sync-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Check playbooks documented
        run: |
          for playbook in deployment/playbooks/*.yml; do
            name=$(basename "$playbook" .yml)
            if ! grep -q "$name" deployment/docs/reference/PLAYBOOKS.md; then
              echo "ERROR: Playbook $name not documented!"
              exit 1
            fi
          done
      
      - name: Validate documentation
        run: bash deployment/docs/validate-docs.sh
```

---

## Summary

**Keep playbooks and docs in sync:**

1. **When changing playbook:** Update docs at the same time
2. **When changing docs:** Verify playbook still matches
3. **Before committing:** Run validation checks
4. **Update CHANGELOG:** Track all changes
5. **Quarterly review:** Systematic sync check

**Result:** Documentation stays accurate and helpful! ✅

---

## Quick Reference

### Files to Update When Making Changes

| Change | Files to Update |
|--------|-----------------|
| Add playbook | PLAYBOOKS.md, relevant guide, README |
| Update playbook | Relevant guide, PLAYBOOKS.md description |
| Delete playbook | PLAYBOOKS.md, all guides mentioning it, README |
| Update guide | CHANGELOG.md |
| Fix error | CHANGELOG.md with "fix:" prefix |
| Change procedure | Related guides, CHANGELOG |
| AWS service change | Affected guides, cost estimates |
| Variable rename | ALL guides, examples, templates |

---

## Need Help?

- **Question:** Check MAINTENANCE_CHECKLIST.md
- **Validation:** Run `deployment/docs/validate-docs.sh`
- **Feedback:** Use FEEDBACK_FORM.md
- **Issue:** Create GitHub issue with label `documentation`

