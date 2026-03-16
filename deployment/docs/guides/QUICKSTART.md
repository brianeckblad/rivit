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

ansible-playbook playbooks/provision-infrastructure.yml \
    --vault-password-file ~/.vault_pass

ansible-playbook -i inventories playbooks/setup.yml \
    --vault-password-file ~/.vault_pass
```

**What it does automatically:**
1. ✅ Creates S3 bucket for application data
2. ✅ Creates IAM role with proper permissions
3. ✅ Creates security group (allows ports 22, 80, 443)
4. ✅ Creates SSH key pair
5. ✅ Launches EC2 instance (Ubuntu 22.04)
6. ✅ Sets up CloudFront CDN (if `enable_cloudfront: true` in `all.yml`)
7. ✅ Configures EC2 with your app
7. ✅ Sets up Nginx web server
8. ✅ Sets up Gunicorn app server
9. ✅ Configures auto-restart with Systemd
10. ✅ Saves server info to `deployment/instance-info.txt`

**Duration:** 10-15 minutes  
**Cost:** ~$0.01 (minimal during creation)

**Alternative: All-in-one script (if available):**
```bash
./scripts/infra-complete-setup.sh
```
---

## Monitoring Progress

While the script runs, you'll see:

```
[AWS Resources]
✅ S3 Bucket: creating...
✅ IAM Role: creating...
✅ Security Group: creating...
✅ SSH Key: creating...
✅ EC2 Instance: launching...

[Configuration]
✅ Deploying application code...
✅ Setting up web server...
✅ Setting up app server...
✅ Starting services...

✅ Deployment Complete!
```

---

## After Deployment

### 1. Get Your Server IP

Your server information is saved in:

```bash
cat deployment/instance-info.txt
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

**See your app running!** 🎉

### 3. Connect via SSH

```bash
# From deployment/instance-info.txt
ssh -i ~/.ssh/{app_name}-key.pem ubuntu@1.2.3.4

# Then check app status
sudo systemctl status {app_name}
```

### 4. View Application Logs

```bash
# From your EC2 instance
sudo journalctl -u {app_name} -f  # Follow logs in real-time
sudo journalctl -u {app_name} -n 50  # Last 50 lines
```

---

## Optional: Add SSL/HTTPS

Your app is currently running on HTTP. To add SSL (HTTPS):

```bash
cd deployment
ansible-playbook -i inventories playbooks/setup-ssl.yml
```

**This will:**
- Install Let's Encrypt certificate
- Configure Nginx for HTTPS
- Redirect HTTP → HTTPS
- Auto-renew certificate

**Requirements:**
- Must have a domain name (not IP address)
- Domain must point to your server IP
- Need to update `server_name` in `group_vars/all.yml`

---

## Troubleshooting

### Script Fails Early

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
   pip3 install ansible
   ```

### Script Fails in Middle

If the script fails partway through:

1. **Check logs:**
   ```bash
   cat deployment/.deployment.log  # Full deployment log
   ```

2. **Resume from that step:**
   - Run individual playbooks instead
   - See [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) for individual commands

3. **Clean up and retry:**
   ```bash
   # Delete the failed infrastructure first (see OPERATIONS.md)
   # Then run the script again
   ```

### Script Completes But App Not Working

1. **Check EC2 is running:**
   ```bash
   aws ec2 describe-instances --region us-east-2
   ```

2. **Check logs on server:**
   ```bash
   ssh -i ~/.ssh/{app_name}-key.pem ubuntu@<IP>
   sudo journalctl -u {app_name} -n 50
   ```

3. **Check website:**
   - Wait 2-3 minutes for services to fully start
   - Try: `curl http://<IP>`
   - Check browser console for errors

4. **Check security group:**
   - Make sure ports 80 and 443 are open
   - See [MANUAL_DEPLOYMENT.md#step-3-create-security-group](MANUAL_DEPLOYMENT.md#step-3-create-security-group)

---

## Next step

Continue to [Chapter 4: Updating Your Application](UPDATING_APPLICATION.md).

## See also

- [Chapter 3: Manual Deployment](MANUAL_DEPLOYMENT.md) — deploy step-by-step instead
- [Chapter 6: Monitoring](MONITORING.md) — set up CloudWatch dashboards and alarms
- [Architecture](../reference/ARCHITECTURE.md) — how the system is designed

