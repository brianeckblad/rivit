# CloudFront CDN Guide

**Speed up your application with global content delivery**

---

## What is CloudFront?

**CDN = Content Delivery Network**

Think of it as:
- **Global cache** - Copies of your content on servers worldwide
- **Fast delivery** - Users download from nearest server
- **Lower bandwidth** - AWS charges less for CloudFront bandwidth
- **DDoS protection** - Built-in with AWS Shield

**Real-world example:**
- Without CloudFront:
  - User in Tokyo → Request to US server → 200ms latency
- With CloudFront:
  - User in Tokyo → Request to Tokyo CDN edge → 20ms latency (10x faster!)

**Cost:** ~$0.085 per GB (varies by region, cheaper than S3)

---

## When to Use CloudFront

### Should Enable If:
- ✅ Serve images/static files (CSS, JS)
- ✅ Global users (not all in one region)
- ✅ High bandwidth usage
- ✅ Need faster load times
- ✅ Want DDoS protection

### Can Skip If:
- ⚠️ Internal-only application
- ⚠️ Only local users
- ⚠️ Very small file sizes
- ⚠️ Static content rarely changes

---

## Quick Setup (5 minutes)

### Option A: Automated Setup (Recommended)

```bash
cd deployment

# Setup CloudFront
ansible-playbook playbooks/setup-cloudfront.yml
```

**What it does:**
- ✅ Creates CloudFront distribution
- ✅ Points to your EC2/ALB
- ✅ Enables caching
- ✅ Sets up HTTP→HTTPS redirect
- ✅ Configures cache behavior
- ✅ Returns CloudFront domain (e.g., d123456.cloudfront.net)

**Duration:** 3-5 minutes (CloudFront takes time to deploy globally)

**Verify:**
```bash
# Get CloudFront domain
aws cloudfront list-distributions \
  --query 'DistributionList.Items[0].DomainName' \
  --output text

# Should return: d123456.cloudfront.net

# Test it works
curl https://d123456.cloudfront.net
# Should return your application
```

### Option B: Manual Setup via AWS Console

1. Go to [CloudFront Console](https://console.aws.amazon.com/cloudfront/)
2. Click **Create distribution**
3. Choose **Web** distribution
4. Origin: Your EC2 IP or ALB domain
5. Viewer protocol policy: Redirect HTTP to HTTPS
6. Enable caching
7. Create

---

## Understanding CloudFront Caching

### How Caching Works

```
User Request:
  ↓
CloudFront Edge (Tokyo)
  ├─ Is content cached?
  ├─ Yes → Return cached, 0ms delay
  └─ No → Fetch from origin (US), cache it, return
     ↓
  Your Origin Server (US)
```

### Cache Behaviors

**Default: Cache everything**
- Images: 1 year
- CSS/JS: 1 year
- HTML: 24 hours

**Configure based on content type:**

```
Static files (images, CSS, JS):
  - Cache: 1 year
  - Changes rarely

HTML pages:
  - Cache: 1 hour (or less)
  - Changes frequently

API responses:
  - Cache: Don't cache (TTL=0)
  - Changes per request
```

### TTL (Time To Live)

**How long CloudFront keeps cached copy before checking origin**

```
TTL = 1 hour (default):
  First user (10:00 AM):
    → Fetch from origin, cache it
  Second user (10:30 AM):
    → Serve from cache (0ms!)
  Third user (11:01 AM):
    → Cache expired, fetch new from origin

Result: Origin server called ~24 times/day instead of 1000s of times
```

---

## Cache Invalidation

**When you update content, CloudFront might still serve old version**

### Option A: Automatic Expiry

```
After TTL expires, CloudFront fetches fresh content automatically
Pro: Works automatically
Con: Users get old content until TTL expires
```

### Option B: Manual Invalidation (Recommended)

```bash
# After deploying new version
# Invalidate the cache

# Get distribution ID
DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query 'DistributionList.Items[0].Id' \
  --output text)

# Invalidate all files
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

# Or invalidate specific files
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/index.html" "/styles.css" "/app.js"
```

**Duration:** 2-5 minutes (invalidation propagates globally)

**Cost:** Free for first 3,000 invalidations/month

### Option C: Version Hashing (Best Practice)

Don't invalidate - use version numbers in filenames:

```
Instead of: /static/styles.css
Use: /static/styles-v1.2.3.css

When deploying new version:
  - Update HTML to reference v1.2.4.css
  - Old v1.2.3.css stays cached (won't change)
  - New v1.2.4.css is downloaded fresh
  
Result: No invalidation needed, both cached appropriately
```

---

## CloudFront Behaviors

### What Gets Cached

**By default:**
- ✅ Images (.jpg, .png, .gif, .svg)
- ✅ Stylesheets (.css)
- ✅ JavaScript (.js)
- ✅ Fonts (.woff, .ttf)
- ✅ Static files (.pdf, .zip)

**NOT cached by default:**
- ❌ HTML pages (depends on TTL)
- ❌ API responses (depends on headers)
- ❌ Dynamic content (depends on headers)

### Configure Caching Behavior

```bash
# Via AWS Console:
1. Go to CloudFront → Distributions → Your distribution
2. Click Behaviors tab
3. Select behavior (or create new)
4. Edit:
   - Path Pattern: /static/* for static files
   - TTL: 31536000 (1 year for static files)
   - Viewer Protocol: Redirect HTTP to HTTPS
```

### Example Configurations

**Static Assets (CSS, JS, Images):**
```
Path Pattern: /static/*
Minimum TTL: 0
Default TTL: 31536000 (1 year)
Maximum TTL: 31536000
Compress: Yes
```

**HTML Pages:**
```
Path Pattern: /*.html
Minimum TTL: 0
Default TTL: 3600 (1 hour)
Maximum TTL: 86400 (1 day)
Compress: Yes
```

**API Endpoints:**
```
Path Pattern: /api/*
Minimum TTL: 0
Default TTL: 0 (no caching)
Maximum TTL: 0
Forward headers: All
```

---

## Monitoring CloudFront

### View Cache Stats

```bash
# Get cache statistics
aws cloudfront list-distributions \
  --query 'DistributionList.Items[0].[Id,DomainName,Status]'

# Check metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=YOUR_DIST_ID \
  --start-time 2026-02-10T00:00:00Z \
  --end-time 2026-02-17T00:00:00Z \
  --period 86400 \
  --statistics Average
```

### Monitor in AWS Console

```
Go to: CloudFront → Distributions → Your distribution → Monitoring

View:
  - Cache hit rate (% of requests served from cache)
  - Bandwidth usage
  - Request count
  - Error rates
  - Bytes downloaded
```

**Good cache hit rate: > 80%** (means 80% of requests served from cache)

### Create Alarms

```bash
# Alert if cache hit rate drops below 70%
aws cloudwatch put-metric-alarm \
  --alarm-name cloudfront-low-hit-rate \
  --alarm-description "Alert if cache hit rate < 70%" \
  --metric-name CacheHitRate \
  --namespace AWS/CloudFront \
  --dimensions Name=DistributionId,Value=YOUR_DIST_ID \
  --statistic Average \
  --period 3600 \
  --threshold 70 \
  --comparison-operator LessThanThreshold
```

---

## Using CloudFront Domain in Application

### Option A: Use CloudFront for All Content

**Update your application to use CloudFront domain:**

```html
<!-- Before -->
<img src="https://your-domain.com/static/image.jpg">
<script src="https://your-domain.com/static/app.js"></script>

<!-- After (using CloudFront) -->
<img src="https://d123456.cloudfront.net/static/image.jpg">
<script src="https://d123456.cloudfront.net/static/app.js"></script>
```

### Option B: Use Your Domain (Better)

**Point your domain to CloudFront instead:**

```bash
# Get CloudFront domain
aws cloudfront list-distributions \
  --query 'DistributionList.Items[0].DomainName' \
  --output text

# In your DNS provider (Route53, GoDaddy, etc.):
# Create CNAME record:
#   your-domain.com → d123456.cloudfront.net
```

**Now your application still uses your domain, but served via CloudFront!**

### Option C: Use S3 Origin for Static Files

**Best practice: Store static files in S3**

```bash
# Upload static files to S3
aws s3 sync /path/to/static/ s3://your-bucket/static/ \
  --cache-control "max-age=31536000"

# Configure CloudFront to use S3:
# Origin: your-bucket.s3.amazonaws.com
# Path: /static/*
```

**Benefits:**
- ✅ Costs less (S3 + CloudFront cheaper than serving from EC2)
- ✅ Scales automatically
- ✅ Your EC2 focuses on app logic only

---

## Cost Optimization

### How CloudFront Saves Money

```
Scenario: 100GB transferred monthly

Without CloudFront:
  - EC2 data transfer out: 100GB × $0.09 = $9
  - Total: $9/month

With CloudFront:
  - CloudFront distribution: ~$5
  - Bandwidth to edge: 100GB × $0.085 = $8.50
  - Total: ~$13.50/month

Wait, it's more expensive!
But:
  - Users get 10x faster speeds
  - EC2 load reduced (can use smaller instance)
  - Included DDoS protection (Shield Standard)
  - Better user experience

Real savings: Smaller EC2 instance + better performance
```

### Ways to Reduce CloudFront Costs

1. **Compress content:**
   ```bash
   # CloudFront automatically compresses:
   # - HTML, CSS, JSON
   # - JavaScript
   # - Text files
   
   # Reduces bandwidth ~80%
   ```

2. **Set appropriate TTLs:**
   ```
   Static files: 1 year TTL (cached forever)
   → Only fetched from origin once
   
   Dynamic content: 1 hour TTL
   → Refreshed periodically, not every request
   ```

3. **Use S3 for static files:**
   ```
   S3 origin cheaper than EC2 origin
   S3 + CloudFront = optimal cost
   ```

4. **Minimize origins:**
   ```
   One CloudFront distribution → EC2
   vs
   Multiple distributions → Higher cost
   
   Keep it simple
   ```

---

## Troubleshooting

### CloudFront Serving Old Content

```bash
# Problem: Updated file but users see old version

# Solution 1: Wait for TTL to expire
# Solution 2: Manually invalidate cache
aws cloudfront create-invalidation \
  --distribution-id YOUR_DIST_ID \
  --paths "/*"

# Solution 3: Set lower TTL for frequently changing files
```

### Users Can't Access CloudFront Domain

```bash
# Check distribution is deployed
aws cloudfront list-distributions \
  --query 'DistributionList.Items[0].Status'
# Should show: "Deployed" (takes 5-10 min)

# Check origin is accessible
# Verify EC2/ALB allows traffic from CloudFront
# May need to add CloudFront IP ranges to security group
```

### Cache Hit Rate Too Low

```bash
# Problem: Most requests hit origin, not cache

# Likely causes:
# 1. TTL too short - increase it
# 2. Cookies preventing caching - use whitelist
# 3. Headers preventing cache - check CloudFront behavior settings
# 4. Dynamic content - that's expected (use 0 TTL for API)

# Solution: Configure caching behavior per path:
aws cloudfront get-distribution-config --id YOUR_DIST_ID
# Edit the DistributionConfig, add cache behaviors
```

### High Bandwidth Costs

```bash
# Check what's using bandwidth
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name BytesDownloaded \
  --dimensions Name=DistributionId,Value=YOUR_DIST_ID \
  --start-time 2026-02-10T00:00:00Z \
  --end-time 2026-02-17T00:00:00Z \
  --period 86400 \
  --statistics Sum

# If high:
# 1. Check for large files (videos, etc.)
# 2. Compress more aggressively
# 3. Move video/large files to S3 with lifecycle policies
```

---

## Advanced: Using CloudFront with WAF

**Combine CloudFront + WAF for maximum protection**

```bash
# Setup WAF
ansible-playbook playbooks/setup-waf.yml

# Attach WAF to CloudFront:
# In WAF setup, scope = CLOUDFRONT (not REGIONAL)
# This protects all traffic before hitting origin
```

**Flow:**
```
User Request
  ↓
WAF (blocks attacks)
  ↓
CloudFront Edge (serves cached)
  ↓
Your Origin (only if not cached)
```

---

## Performance Tips

### Measure Speed

```bash
# Before CloudFront
time curl https://your-ip/image.jpg

# After CloudFront
time curl https://your-cloudfront-domain/image.jpg

# Should be 5-10x faster for first request
# Even faster for subsequent requests (cached)
```

### Use Compression

```bash
# CloudFront auto-compresses text files
# For custom compression:

gzip -9 /path/to/large.js

# CloudFront will serve .js.gz to browsers that support it
# ~80% size reduction
```

### Optimize Images

```bash
# CloudFront caches images as-is
# Pre-optimize them:

# Use ImageMagick or similar
convert image.jpg -quality 85 -strip image-optimized.jpg

# Result: 50% smaller, still good quality
```

---

## Next Steps

- **Setup:** Run `ansible-playbook playbooks/setup-cloudfront.yml`
- **Configuration:** See [#cloudfront-behaviors](#cloudfront-behaviors)
- **Monitor:** Check CloudWatch metrics weekly
- **Optimize:** Adjust TTLs based on cache hit rate
- **WAF:** Combine with [WAF_CONFIGURATION.md](WAF_CONFIGURATION.md) for full protection
- **Operations:** See [OPERATIONS.md](OPERATIONS.md) for ongoing monitoring

---

## Summary

**CloudFront provides:**
- ✅ 10x faster content delivery
- ✅ Global edge locations
- ✅ DDoS protection (Shield Standard)
- ✅ Cost savings on bandwidth
- ✅ Automatic compression
- ✅ Cache invalidation control

**Setup takes:**
- ⚡ 5 minutes (automated)
- 🔧 10-15 minutes (manual setup)

**Costs:**
- 💰 $5-50/month (depending on data transferred)
- 💾 Saves money if serving static files

**Your users will thank you for the speed!** ⚡

