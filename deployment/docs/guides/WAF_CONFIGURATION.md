# Chapter 11: WAF Configuration

Block attacks at the network edge before they reach your server.

---

## What is WAF?

AWS WAF (Web Application Firewall) inspects incoming HTTP requests and blocks those that match known attack patterns. It provides rule-based filtering, rate limiting, and geographic restrictions.
- **Bot detection** - Block malicious bots

**Key difference from regular firewall:**
- Regular firewall: Blocks/allows ports (22, 80, 443)
- WAF: Blocks/allows specific HTTP requests (SQL injection, XSS, etc.)

**Cost:** ~$5/month + per-rule costs (usually $1-2 per rule)

---

## When to Use WAF

### Should Enable WAF If:
- ✅ Public-facing application
- ✅ Handles user input
- ✅ Stores sensitive data
- ✅ Receives attacks/spam
- ✅ Need compliance (PCI-DSS, HIPAA)

### Can Skip WAF If:
- ⚠️ Internal-only application
- ⚠️ No user input
- ⚠️ MVP stage (add later)
- ⚠️ Very low traffic

---

## Quick Setup (10 minutes)

### Option A: AWS Managed Rules (Recommended)

**Recommended** - AWS updates rules for you

```bash
cd deployment

# Setup WAF with AWS managed rules
ansible-playbook playbooks/setup-waf.yml \
    --vault-password-file ~/.vault_pass
```

**What it does:**
- ✅ Creates WAF Web ACL
- ✅ Attaches AWS managed rules:
  - AWS Core Rule Set (SQL injection, XSS, etc.)
  - AWS Known Bad Inputs
  - AWS IP Reputation List
  - Rate limiting rule
- ✅ Associates with CloudFront or ALB

**Duration:** 2-3 minutes

**Verify:**
```bash
# Check WAF is created
aws wafv2 list-web-acls --region us-east-2 --scope CLOUDFRONT

# Should show your WAF with name like "{app_name}-waf"
```

### Option B: Manual Setup via AWS Console

1. Go to [AWS WAF Console](https://console.aws.amazon.com/wafv2/)
2. Click **Create Web ACL**
3. Name: `{app_name}-waf`
4. CloudFront distribution (if using CDN)
5. Add rules (see Rules section below)
6. Review and create

---

## Understanding WAF Rules

### Rule Types

**1. AWS Managed Rules** (Easiest)
- Pre-built by AWS security team
- Updated automatically
- Cover most common attacks
- No code needed

**2. Custom Rules** (More control)
- You define the conditions
- Match IP, headers, body, URL, etc.
- Good for app-specific blocking

**3. Rate-Based Rules** (Anti-DDoS)
- Block if IP makes too many requests
- Example: > 2000 requests/5 minutes
- Effective against DDoS

---

## Common Rules to Enable

### Rule 1: SQL Injection Protection

**What it blocks:**
- `?id=1' OR '1'='1`
- `'; DROP TABLE users;--`
- `%27 UNION SELECT`

**Setup:**
```bash
# Via playbook (already included in setup-waf.yml)
# Or via AWS Console:

1. Go to WAF Rules
2. Add Managed Rule Group
3. AWS Core Rule Set
4. Enable "SQLi"
```

### Rule 2: XSS (Cross-Site Scripting) Protection

**What it blocks:**
- `<script>alert('xss')</script>`
- `<img src=x onerror="alert('xss')">`
- `javascript:void(0)`

**Setup:**
```bash
# Included in AWS Core Rule Set
# Automatically enabled
```

### Rule 3: Rate Limiting (Anti-DDoS)

**What it blocks:**
- Single IP making > 2000 requests in 5 minutes
- Automated attacks/crawlers

**Setup:**
```
Create Rule:
- Type: Rate-based
- Limit: 2000 requests per 5 minutes
- Action: Block
```

**For your app:**
- Normal user: ~50-100 requests/5 min
- Crawler/bot: 1000+ requests/5 min
- DDoS: 10,000+ requests/5 min

### Rule 4: Geo-Blocking (Optional)

**What it blocks:**
- Requests from specific countries
- Example: Block traffic from high-attack countries

**Setup:**
```
Create Rule:
- Type: Geo-match
- Countries: [China, Russia, etc.]
- Action: Block
```

**Caution:** May block legitimate users if they use VPN

### Rule 5: IP Reputation (AWS Managed)

**What it blocks:**
- Known malicious IPs
- Compromised servers
- Botnets

**Automatically enabled in:**
- AWS Managed Rule Group
- IP Reputation List

---

## Blocking Specific IPs

### Block Single IP

```bash
# Via AWS Console:
1. Go to WAF → Web ACLs → Your WAF
2. Rules tab
3. Add custom rule
4. Type: IP set
5. Match condition: IP = ATTACKER_IP
6. Action: Block

# Via CLI:
aws wafv2 create-ip-set \
  --name {app_name}-blocked-ips \
  --scope CLOUDFRONT \
  --region us-east-2 \
  --ip-address-version IPV4 \
  --addresses ["X.X.X.X/32"]
```

### Block Entire Subnet

```bash
# Block a /24 subnet (256 IPs)
aws wafv2 update-ip-set \
  --name {app_name}-blocked-ips \
  --scope CLOUDFRONT \
  --region us-east-2 \
  --id ID_FROM_ABOVE \
  --addresses ["X.X.X.0/24"]
```

### Block Based on Country

```bash
# Block all traffic from China
aws wafv2 create-rule \
  --name block-china \
  --action BLOCK \
  --geo-match-statement-properties country-codes=[CN]
```

---

## Monitoring WAF

### View Blocked Requests

```bash
# Via AWS Console:
1. Go to WAF → Web ACLs → Your WAF
2. Requests tab
3. Blocked requests shown with reason

# Via CloudWatch:
1. Go to CloudWatch → Logs
2. Look for /aws/waf/{app_name}/
3. Filter for "BLOCK" action
```

### Check What Rules Are Blocking

```bash
# Via CLI:
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=Rule,Value=RateLimitRule \
  --start-time 2026-02-16T00:00:00Z \
  --end-time 2026-02-17T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Create CloudWatch Alarms

```bash
# Alert if blocked requests spike
aws cloudwatch put-metric-alarm \
  --alarm-name {app_name}-waf-blocked-spike \
  --alarm-description "Alert if WAF blocks > 100 requests/min" \
  --metric-name BlockedRequests \
  --namespace AWS/WAFV2 \
  --statistic Sum \
  --period 60 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

---

## Handling False Positives

**Sometimes WAF blocks legitimate traffic.**

### Identify False Positives

```bash
# Check blocked request details
# Go to AWS Console → WAF → Web ACLs → Your WAF → Requests

# Look for:
- Your own testing requests
- Legitimate user requests
- API calls

# Example: Rate limiting false positive
- Mobile app makes 3000 requests/5 min (excessive pagination)
- WAF blocks it
- Need to either:
  a) Whitelist the IP
  b) Increase rate limit threshold
  c) Fix app to be more efficient
```

### Whitelist IPs (Bypass WAF)

```bash
# Create IP set for whitelist
aws wafv2 create-ip-set \
  --name {app_name}-whitelist \
  --scope CLOUDFRONT \
  --region us-east-2 \
  --ip-address-version IPV4 \
  --addresses ["YOUR_OFFICE_IP/32", "YOUR_HOME_IP/32"]

# Create rule to allow whitelist
# Rule Type: IP set
# IP set: {app_name}-whitelist
# Action: Allow (Count only)
```

### Disable Rule Temporarily

```bash
# If a rule is too aggressive:
1. Go to WAF → Web ACLs → Your WAF
2. Click on rule
3. Set to "Count" instead of "Block"
   - Logs requests but doesn't block
4. Monitor for a few hours
5. Adjust and re-enable as "Block"
```

---

## DDoS Attack Response

**If you're under DDoS attack:**

### Step 1: Check CloudWatch

```bash
# Go to CloudWatch → WAF metrics
# Look for "AllowedRequests" and "BlockedRequests"

# Normal: Even distribution
# DDoS: Spike in requests from few IPs
```

### Step 2: Identify Attack Source

```bash
# Get top IPs hitting your site
aws logs insights query: \
  fields httpRequest.clientIp as ip | \
  stats count() by ip | \
  sort count() desc | \
  limit 10
```

### Step 3: Block Attack IPs

```bash
# Create rule to block them
aws wafv2 create-ip-set \
  --name ddos-attack-ips \
  --scope CLOUDFRONT \
  --region us-east-2 \
  --ip-address-version IPV4 \
  --addresses ["X.X.X.X/32", "Y.Y.Y.Y/32"]

# Add to WAF
# Set action to: Block
```

### Step 4: Increase Rate Limiting

```bash
# Temporarily lower threshold during attack
# Example: Change from 2000 to 1000 req/5 min

# AWS will automatically start blocking more IPs
```

### Step 5: Escalate if Needed

```bash
# If still under attack:
- Enable AWS Shield Standard (free, automatic)
- Upgrade to AWS Shield Advanced (~$3000/month, includes DDoS support)
- Contact AWS Support
```

---

## WAF Costs

### Free:
- ✅ Web ACL
- ✅ AWS Managed Rules (usually)

### Paid:
- Custom rules: $1-5 per rule per month
- Requests evaluated: First 10M free, then $0.36 per 1M

### Example:
- Basic setup (AWS managed rules): ~$5/month
- 100M requests: $5 + $32 = $37/month
- 1B requests: $5 + $320 = $325/month

**Worth it if:**
- ✅ Website receives attacks
- ✅ Handles sensitive data
- ✅ Need compliance

**Save money:**
- Use rate limiting instead of manual rules
- Use AWS managed rules (included)
- Monitor and disable unused rules

---

## Testing WAF Rules

### Test SQL Injection Rule

```bash
# This should be blocked
curl "http://YOUR_DOMAIN/?id=1' OR '1'='1"

# Expected: 403 Forbidden
# WAF blocked it

# This should be allowed
curl "http://YOUR_DOMAIN/?id=123"

# Expected: 200 OK
# Normal traffic allowed
```

### Test Rate Limiting

```bash
# Make 2100 requests in 5 minutes
for i in {1..2100}; do
  curl http://YOUR_DOMAIN/ > /dev/null 2>&1
done

# After 2000, subsequent requests should get 403
curl http://YOUR_DOMAIN/
# Expected: 403 Forbidden
```

### Test Geo-Blocking

```bash
# If you blocked specific countries:
# This requires spoofing country header (not real-world test)
# Better to test in AWS Console with "Count" mode first
```

---

## Troubleshooting

### Users Getting 403 Blocked

**Problem:** Legitimate users see 403 errors

**Diagnosis:**
```bash
# Check WAF logs
aws logs tail /aws/waf/{app_name}/ --follow

# Look for "BLOCK" entries
# Note the rule name that blocked
```

**Solution:**
1. Is it false positive? Add IP to whitelist
2. Is rate limit too low? Increase threshold
3. Is rule too strict? Adjust rule conditions
4. Is it a known attack? Keep blocking

### WAF Not Blocking Expected Traffic

**Problem:** Attack traffic still getting through

**Diagnosis:**
```bash
# Check if WAF is associated with CloudFront/ALB
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn arn:aws:wafv2:... \
  --region us-east-2

# Should show CloudFront distribution
```

**Solution:**
1. Verify WAF is attached to correct resource
2. Check rule is in "Block" mode (not "Count")
3. Check rule conditions match attack pattern
4. Add more specific rule

### Cost Too High

**Problem:** WAF bill higher than expected

**Solutions:**
1. Reduce custom rules (keep only necessary)
2. Use rate limiting instead of custom rules
3. Check request volume (are you being scanned?)
4. Disable geo-blocking if not needed
5. Use AWS Shield Advanced for DDoS (includes DDoS support credit)

---

## WAF Best Practices

### Do's ✅
- ✅ Start with AWS managed rules
- ✅ Use "Count" mode first, then "Block"
- ✅ Monitor blocked requests
- ✅ Document why each rule exists
- ✅ Review rules quarterly
- ✅ Alert on sudden blocked request spikes
- ✅ Have whitelist for internal IPs
- ✅ Test rules before enabling

### Don'ts ❌
- ❌ Block entire countries without reason
- ❌ Set rate limit too low (blocks legitimate traffic)
- ❌ Forget to whitelist office IP (blocks yourself!)
- ❌ Create too many custom rules (costs money)
- ❌ Never update rules (threats evolve)
- ❌ Ignore false positives (user experience)
- ❌ Set only to "Count" (not actually blocking)

---


## Summary

**WAF blocks:**
- ✅ SQL injection attacks
- ✅ XSS (cross-site scripting)
- ✅ DDoS attacks (via rate limiting)
- Malicious bots
- Traffic from specific countries/IPs

Cost: $5–50/month depending on rules and traffic volume.

---

## Next step

Continue to [Chapter 12: Git Configuration](GIT_CONFIGURATION.md).

## See also

- [Chapter 10: CloudFront CDN](CLOUDFRONT_CDN.md) — attach WAF to CloudFront
- [Application Security](../reference/APPLICATION_SECURITY.md) — security layers reference

