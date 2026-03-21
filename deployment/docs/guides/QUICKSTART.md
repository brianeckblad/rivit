# Chapter 2: Quick Start

Deploy the application in 15–20 minutes using automation.

> **Prerequisite:** Complete [Chapter 1: Prerequisites](PREREQUISITES.md) before continuing.

---

## Load Configuration Variables

Before running commands, load your deployment variables:

```bash
cd deployment

# IMPORTANT: Use 'source' command
source scripts/load-vars.sh
```

**You should see:**
```
✅ Variables loaded and EXPORTED successfully

Available variables (exported to this shell):
  app_name=rampe
  app_display_name=Rampe Application
  aws_region=us-east-2
  admin_user=ubuntu
  server_name=rampe.ipix.io

Variables are NOW AVAILABLE in your shell. Try these commands:
  echo $app_name
  aws s3 ls | grep $app_name
  aws iam get-role --role-name ${app_name}-ec2-role
```

Now your variables are available in all CLI commands:
```bash
echo $app_name           # Shows: rampe
echo $aws_region         # Shows: us-east-2
aws s3 ls | grep $app_name
```


---

## Quick Deploy (10-15 minutes)

Everything is automated with playbooks:

```bash
cd deployment

# Variables already loaded from previous step
# Now run the deployment playbooks

# 1. Create AWS resources (S3, IAM, SG, SSH key, EC2, Secrets Manager)
ansible-playbook playbooks/provision-infrastructure.yml \
    --vault-password-file ~/.vault_pass

# 2. Prepare the server (system packages, app user, EBS volume mount)
ansible-playbook playbooks/setup-server.yml \
    --vault-password-file ~/.vault_pass

# 3. Deploy the application (code, dependencies, Nginx, Supervisor)
ansible-playbook playbooks/setup.yml \
    --vault-password-file ~/.vault_pass
```

**What it does automatically:**

`provision-infrastructure.yml`:
1. ✅ Creates S3 bucket for application data
2. ✅ Creates IAM role with proper permissions
3. ✅ Creates security group (allows ports 22, 80, 443)
4. ✅ Creates SSH key pair
5. ✅ Launches EC2 instance (Ubuntu 22.04)
6. ✅ Creates Secrets Manager secret (synced from vault)
7. ✅ Sets up CloudFront CDN (if `enable_cloudfront: true` in vault.yml)

`setup-server.yml`:
8. ✅ Installs system packages (Python, Nginx, git)
9. ✅ Creates dedicated app user
10. ✅ Formats and mounts EBS data volume

`setup.yml`:
11. ✅ Clones code and installs Python dependencies
12. ✅ Configures Nginx and Supervisor
13. ✅ Starts the application

**Duration:** 10-15 minutes
**Cost:** ~$0.01 (minimal during creation)

---

## After Deployment

### 1. Get Your Server IP

Your server information is saved in `deployment/instances/`:

```bash
ls deployment/instances/
cat deployment/instances/*.txt
```

Shows:
```
Server IP:     1.2.3.4
Instance ID:   i-xxxxx
SSH Command:   ssh -i ~/.ssh/{app_name}-key.pem ubuntu@1.2.3.4
```

### 2. Test Your Application

```bash
# In your browser:
http://1.2.3.4

# Or from terminal:
curl http://1.2.3.4
```

### 3. Connect via SSH

```bash
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@1.2.3.4

# Check app status
sudo supervisorctl status {app_name}
```

### 4. View Application Logs

```bash
# From your EC2 instance
sudo tail -f /opt/{app_name}/logs/app.log      # Application logs
sudo tail -f /var/log/nginx/access.log          # Nginx access logs
```

---

## Optional: Add SSL/HTTPS

Your app is currently running on HTTP. To add SSL (HTTPS):

```bash
cd deployment
ansible-playbook playbooks/setup-ssl.yml --vault-password-file ~/.vault_pass
```

**This will:**
- Install Let's Encrypt certificate
- Configure Nginx for HTTPS
- Redirect HTTP → HTTPS
- Auto-renew certificate

**Requirements:**
- Must have a domain name (not IP address)
- Domain must point to your server IP
- Need to update `server_name` in vault.yml (`ansible-vault edit group_vars/vault.yml`)

---

## Troubleshooting

### Playbook Fails Early

**Common issues:**
1. AWS CLI not working
   ```bash
   aws sts get-caller-identity
   ```

2. Vault not encrypted
   ```bash
   head -1 deployment/group_vars/vault.yml
   # Should show: $ANSIBLE_VAULT;1.1;AES256
   ```

3. Vault password file missing
   ```bash
   ls -la ~/.vault_pass
   # Should show: -rw------- (600 permissions)
   ```

4. Ansible not installed
   ```bash
   cd deployment
   pip install -r requirements.txt
   ```

### Playbook Fails in Middle

If a playbook fails partway through:

1. **Fix the issue** and re-run the same playbook — Ansible is idempotent, it skips completed steps.

2. **Or run individual playbooks** for the failed step only. See [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) for individual commands.

### Deployment Completes But App Not Working

1. **Check EC2 is running:**
   ```bash
   aws ec2 describe-instances --region $aws_region \
       --filters "Name=tag:Name,Values=$app_name" \
       --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'
   ```

2. **Check app on server:**
   ```bash
   ssh -i ~/.ssh/{app_name}-key.pem ubuntu@<IP>
   sudo supervisorctl status {app_name}
   sudo tail -50 /opt/{app_name}/logs/app.log
   ```

3. **Check web server:**
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   ```

4. **Wait 2-3 minutes** for services to fully start, then try `curl http://<IP>`.

---

## Next step

Continue to [Chapter 4: Updating Your Application](UPDATING_APPLICATION.md).

## See also

- [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) — deploy step-by-step instead
- [Chapter 6: Monitoring](MONITORING.md) — set up CloudWatch dashboards and alarms
- [Architecture](../reference/ARCHITECTURE.md) — how the system is designed

