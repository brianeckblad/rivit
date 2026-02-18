# Documentation Maintenance Checklist

**Quarterly review and update process for deployment documentation**

---

## Quarterly Review Schedule

**Review Date:** Every 3 months (Feb, May, Aug, Nov)

Run this checklist to keep documentation in sync with code.

---

## Review Tasks

### Week 1: Documentation Accuracy

- [ ] Check all playbooks still exist (may have been renamed/deleted)
  ```bash
  cd deployment/playbooks
  ls -1 *.yml | sort
  # Compare with PLAYBOOKS.md reference table
  ```

- [ ] Verify all AWS services mentioned in docs still exist
  - CloudFront (still best CDN?)
  - WAF (pricing still reasonable?)
  - S3 (storage still needed?)
  - Check for AWS service discontinuations

- [ ] Check AWS Console UI hasn't changed significantly
  - Screenshots (if any) still match
  - Menu paths still valid
  - Policy names still exist
  
- [ ] Verify all commands still work
  ```bash
  # Test sample commands from guides
  aws sts get-caller-identity
  ansible --version
  ansible-playbook --version
  ```

- [ ] Check all file paths still valid
  - `/var/log/{app_name}/` still where logs go?
  - `/home/ubuntu/{app_name}` still where app deployed?
  - Configuration file locations unchanged?

### Week 2: Feature Updates

- [ ] Check for new AWS features to document
  - New CloudWatch features?
  - New WAF capabilities?
  - Cheaper alternatives to current services?
  
- [ ] Check for AWS service updates/deprecations
  ```bash
  # Subscribe to AWS Blog
  # https://aws.amazon.com/blogs/
  
  # Check service status pages
  # https://status.aws.amazon.com/
  ```

- [ ] Review GitHub issues/discussions for common problems
  - Are users getting stuck on any step?
  - Are there outdated instructions causing issues?
  - Do any playbooks fail frequently?

- [ ] Check if new playbooks were added
  - Run: `ls -la deployment/playbooks/*.yml | wc -l`
  - If more than last quarter, document new ones

- [ ] Review latest deployments
  - Did anything break?
  - Were workarounds needed?
  - Should guide be updated?

### Week 3: Documentation Quality

- [ ] Check for broken links in docs
  ```bash
  # Find all markdown links
  grep -r "\[.*\](" deployment/docs/guides/ deployment/docs/reference/
  
  # Manually verify they point to valid files
  # Look for:
  # - (NONEXISTENT.md)
  # - (#broken-anchor)
  # - Paths with typos
  ```

- [ ] Review code examples for accuracy
  - Do bash scripts match actual CLI syntax?
  - Do playbook names match actual files?
  - Do variable names match actual configs?

- [ ] Check for out-of-date information
  - Cost estimates (are they still accurate?)
  - Time estimates (15 min deploy still true?)
  - Service names/features (still current?)

- [ ] Review IAM permissions
  - Are managed policy names still valid?
  - Have new policies been introduced?
  - Are least-privilege recommendations still accurate?

- [ ] Check SSL/certificate information
  - Let's Encrypt still free?
  - Renewal process unchanged?
  - Auto-renewal still working?

### Week 4: Real-World Examples

- [ ] Collect feedback from recent deployments
  - What questions did users ask?
  - What steps were confusing?
  - What took longer than expected?

- [ ] Add real-world examples to guides
  - Common errors and how to fix them
  - Deployment scenarios (dev vs prod)
  - Customization examples

- [ ] Update cost estimates if needed
  ```bash
  # Check current AWS pricing
  # https://aws.amazon.com/ec2/pricing/
  # https://aws.amazon.com/s3/pricing/
  # https://aws.amazon.com/cloudfront/pricing/
  # https://aws.amazon.com/waf/pricing/
  ```

- [ ] Update time estimates if needed
  - Measure actual deployment time
  - Note if any steps consistently take longer
  - Update documentation with realistic times

- [ ] Add new troubleshooting sections
  - What issues came up?
  - How were they solved?
  - Add to relevant guide

---

## Specific Guide Updates

### PREREQUISITES.md - Annual Review
- [ ] AWS account setup still the same process?
- [ ] IAM permissions names unchanged?
- [ ] AWS CLI installation instructions still accurate?
- [ ] Configuration file format still valid?

### INFRASTRUCTURE.md - Every 6 Months
- [ ] EC2 instance types still recommended?
- [ ] S3 bucket naming conventions still required?
- [ ] Security group rules still necessary?
- [ ] SSH key format still correct?
- [ ] Any new AWS regions recommended?

### QUICKSTART.md - Every 3 Months
- [ ] All commands still work?
- [ ] 15-20 minute estimate still accurate?
- [ ] Playbook names match actual files?
- [ ] Instance type (t3.micro) still free-tier eligible?

### MANUAL_DEPLOYMENT.md - Every 3 Months
- [ ] Step-by-step instructions still complete?
- [ ] Manual SSH commands still valid?
- [ ] Systemd service file format unchanged?
- [ ] Nginx configuration still correct?

### UPDATING_APPLICATION.md - Every 3 Months
- [ ] Playbook names still correct?
- [ ] Rollback procedures still work?
- [ ] Zero-downtime strategy still valid?

### SECURITY_HARDENING.md - Every 3 Months
- [ ] SSH hardening still best practices?
- [ ] Fail2ban still available/recommended?
- [ ] UFW firewall still standard?
- [ ] Auto-update procedures unchanged?

### WAF_CONFIGURATION.md - Every 6 Months
- [ ] AWS WAF still the best choice?
- [ ] Pricing structure unchanged?
- [ ] Managed rules still up-to-date?
- [ ] DDoS protection methods still current?

### CLOUDFRONT_CDN.md - Every 6 Months
- [ ] CloudFront still best CDN for AWS?
- [ ] Pricing still accurate?
- [ ] Cache invalidation procedure unchanged?
- [ ] Any new features to document?

### MONITORING.md - Every 3 Months
- [ ] CloudWatch features unchanged?
- [ ] Alarm creation process still the same?
- [ ] Dashboard widgets still available?
- [ ] Pricing still accurate?

### OPERATIONS.md - Every 3 Months
- [ ] Daily/weekly/monthly tasks still relevant?
- [ ] SSL renewal still automatic?
- [ ] Backup procedures still work?
- [ ] Monitoring procedures still accurate?

---

## Process

### Monthly Quick Check (5 minutes)
```bash
# Check for errors in recent deployments
# Email: "Any issues this month?"

# Scan GitHub issues/discussions
# Look for common questions

# Check AWS status page for outages
# https://status.aws.amazon.com/
```

### Quarterly Deep Review (2 hours)
```bash
# Run through all items above
# Update documentation as needed
# Test key procedures (don't deploy, just dry-run)

# Example:
cd deployment
ansible-playbook playbooks/setup-ssl.yml --check
# (verify playbook syntax still valid)
```

### Annual Comprehensive Update (4 hours)
```bash
# Full review of all documentation
# Update all cost estimates
# Review AWS announcements from past year
# Test complete deployment (in test environment)
# Update architecture diagrams if any
```

---

## Documentation Update Process

When you find something to update:

1. **Identify the issue**
   - Which guide needs updating?
   - What changed?
   - Why does it matter?

2. **Make the change**
   ```bash
   cd /path/to/rampe
   # Edit the file(s)
   nano deployment/docs/guides/GUIDE_NAME.md
   ```

3. **Test it**
   ```bash
   # If commands: verify they still work
   # If procedures: verify they're still accurate
   # If links: verify they point to valid locations
   ```

4. **Commit and push**
   ```bash
   git add deployment/docs/guides/GUIDE_NAME.md
   git commit -m "docs: update GUIDE_NAME for [reason]
   
   - Fixed [specific issue]
   - Updated [changed procedure]
   - Added [new information]"
   git push origin
   ```

---

## Tracking Changes

### Create a CHANGELOG.md

Keep track of what was updated and when:

```markdown
# Documentation Changelog

## 2026-02-17
- Updated PREREQUISITES.md: Fixed CloudWatch permissions to use inline policy
- Updated MONITORING.md: Added inline policy template

## 2026-02-10
- Created UPDATING_APPLICATION.md
- Created SECURITY_HARDENING.md
- Created WAF_CONFIGURATION.md
- Created CLOUDFRONT_CDN.md
- Updated OPERATIONS.md: Added SSL renewal and decommissioning sections
```

---

## Feedback Loop

### How to Collect Feedback

1. **From deployments**
   - Ask users: "What was confusing?"
   - Track common issues
   - Note what took longer than expected

2. **From GitHub**
   - Monitor Issues for documentation requests
   - Watch Discussions for questions
   - Track errors users report

3. **From team**
   - Ask: "What should we document better?"
   - Collect edge cases you encountered
   - Share lessons learned

### Feedback Template

When collecting feedback, ask:
- [ ] Which guide did you use?
- [ ] What was unclear?
- [ ] Did you get stuck anywhere?
- [ ] How long did deployment take?
- [ ] What would help?
- [ ] Any errors we should document?

---

## Common Updates

### When AWS Changes Something
1. Identify what changed
2. Find all docs mentioning it
3. Update examples
4. Test procedures
5. Commit with "aws:" prefix

Example:
```bash
git commit -m "docs: update for AWS CloudFront pricing change

- Updated cost estimates in CLOUDFRONT_CDN.md
- Added new pricing tiers explanation
- Verified cache behavior still works"
```

### When Feature Is Added
1. Check if any playbook was added
2. Create/update guide for it
3. Add to PLAYBOOKS.md reference
4. Link from relevant existing guides
5. Add examples

Example:
```bash
git commit -m "docs: add guide for new deployment feature

- Created NEW_FEATURE.md
- Updated PLAYBOOKS.md reference table
- Added links from MANUAL_DEPLOYMENT.md"
```

### When Bug Is Fixed
1. Document the issue
2. Document the fix
3. Add to troubleshooting section
4. Add to CHANGELOG

Example:
```bash
git commit -m "docs: add troubleshooting for common SSL renewal issue

- Added 'SSL renewal fails' section to OPERATIONS.md
- Document error and solution
- Link to relevant AWS docs"
```

---

## Automation Ideas

### GitHub Actions Workflow

Could add automated checks:

```yaml
name: Documentation Validation

on:
  pull_request:
    paths:
      - 'deployment/docs/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Check for broken links
        run: |
          # Check all markdown links point to valid files
          grep -r "\[.*\](" deployment/docs/ | \
          sed 's/.*\(\[.*\](\(.*\))\).*/\2/' | \
          while read link; do
            # Check if file exists (if local link)
            if [[ $link == /* ]]; then
              test -f "$link" || echo "Broken: $link"
            fi
          done
      
      - name: Validate bash syntax
        run: |
          # Find bash code blocks
          # Validate they have correct syntax
          echo "Checking bash examples..."
      
      - name: Check for outdated dates
        run: |
          # Flag if dates are > 1 year old
          grep -r "Last Updated:" deployment/docs/ | \
          grep -v "202[6-9]"
```

### Scheduled Reminders

Set calendar reminders:
- Feb 15: Q1 Documentation Review
- May 15: Q2 Documentation Review
- Aug 15: Q3 Documentation Review
- Nov 15: Q4 Documentation Review

---

## Summary

**Quarterly Documentation Review Process:**

| Week | Task | Time |
|------|------|------|
| 1 | Accuracy check | 30 min |
| 2 | Feature updates | 30 min |
| 3 | Quality review | 30 min |
| 4 | Real-world examples | 30 min |
| **Total** | **Complete quarterly review** | **2 hours** |

**Annual Tasks:**
- [ ] Deep AWS service review
- [ ] Update cost estimates
- [ ] Test complete deployment
- [ ] Review and update architecture

**Ongoing:**
- [ ] Monthly quick check (5 min)
- [ ] Collect user feedback
- [ ] Track issues in GitHub
- [ ] Update CHANGELOG.md

**Result:** Documentation stays current, accurate, and helpful! ✅

