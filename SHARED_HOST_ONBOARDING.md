# Shared EC2 Host — New App Onboarding

This document is written for an AI agent (or developer) setting up a **new Flask app
on the same EC2 instance** that already runs the `rampe` app.
Read it completely before making any changes to the new app's repo.

---

## What is already on the server

The server already runs one app with these characteristics:

| Property | Value |
|---|---|
| App name | `rampe` |
| Domain | `rampe.ipix.io` |
| Gunicorn port | `8000` (loopback only: `127.0.0.1:8000`) |
| App directory | `/opt/rampe` |
| Runtime user | `rampe_runtime` |
| Nginx vhost file | `/etc/nginx/sites-available/rampe` |
| Supervisor config | `/etc/supervisor/conf.d/rampe.conf` |
| Log directory | `/var/log/rampe` |
| AWS region | `us-east-2` |
| Deployment user | `ubuntu` |

**Do not touch any of these paths or this port.** The new app must use completely
separate values for everything in the list above.

---

## How traffic routing works

Nginx on this server routes requests by `server_name` (FQDN), not by path or port.
Each app gets:

- Its own DNS record pointing at the server's public IP
- Its own nginx vhost file (`/etc/nginx/sites-available/<app_name>`)
- Its own gunicorn process on a unique `127.0.0.1:<port>`
- Its own SSL certificate (certbot runs per domain)

```
Internet
    │
    ▼
nginx :443 (SSL termination)
    ├─ server_name rampe.ipix.io     → proxy_pass 127.0.0.1:8000 (rampe)
    └─ server_name yourapp.yourdomain.com → proxy_pass 127.0.0.1:8001 (new app)
```

---

## Port allocation

Ports are allocated sequentially on this server:

| Port | App |
|---|---|
| `8000` | rampe ← already taken |
| `8001` | **use this for the next app** |
| `8002` | available for a third app |

Pick the next available port. **Never reuse port 8000.**

---

## What the new app's deployment must look like

The new app needs an Ansible deployment that follows the same pattern as `rampe`.
The key requirements are below.

### 1. `deployment/group_vars/vault.yml` — variables that MUST be unique

These are the values you must set differently from `rampe`. Everything else can
follow the same defaults used by rampe.

```yaml
# APPLICATION IDENTITY — all must be unique per app on this server
app_name: "yourapp"                          # drives all paths, groups, log dirs — no spaces
app_display_name: "Your App Display Name"
server_name: "yourapp.yourdomain.com"        # DNS must already point at the server's public IP
ssl_email: "you@yourdomain.com"
service_name: "{{ app_name }}"

# USERS — app_user must be unique per app
app_user: "yourapp_runtime"                  # e.g. yourapp_runtime — NOT rampe_runtime

# PORT — THE most important value; must not conflict with any existing app
gunicorn_port: "8001"                        # rampe uses 8000 — use 8001 or higher
gunicorn_bind: "127.0.0.1:{{ gunicorn_port }}"
app_port: "{{ gunicorn_port }}"
flask_port: "{{ gunicorn_port }}"

# STORAGE — unique because app_name drives the path
app_dir: "/opt/{{ app_name }}"               # resolves to /opt/yourapp — fine as-is
log_dir: "/var/log/{{ app_name }}"           # resolves to /var/log/yourapp — fine as-is

# AWS — use your own bucket and secret
s3_bucket_name: "yourapp-bucket-name"        # must be globally unique in S3
secret_name: "{{ app_name }}/production"     # resolves to yourapp/production — fine as-is
```

### 2. `deployment/templates/nginx.conf.j2` — required patterns

The nginx template **must** use variables, not hardcoded values. Check every
`proxy_pass` line and every rate-limit zone name.

**`proxy_pass` — must use `{{ gunicorn_bind }}`:**
```nginx
# CORRECT
proxy_pass http://{{ gunicorn_bind }};

# WRONG — hardcoded port will conflict or be wrong
proxy_pass http://127.0.0.1:8000;
```

**Rate-limit zone names — must be prefixed with `{{ app_name }}_`:**
```nginx
# CORRECT — unique zone names per app, no collision
limit_req_zone $binary_remote_addr zone={{ app_name }}_login_limit:10m rate=20r/m;
limit_req_zone $binary_remote_addr zone={{ app_name }}_api_limit:10m rate=200r/m;
limit_req_zone $binary_remote_addr zone={{ app_name }}_general_limit:10m rate=300r/m;

# CORRECT — references must match
limit_req zone={{ app_name }}_login_limit burst=30 nodelay;

# WRONG — bare zone names collide when nginx loads configs for both apps
limit_req_zone $binary_remote_addr zone=login_limit:10m rate=20r/m;
```

**`server_name` — must use the vault variable:**
```nginx
server_name {{ server_name | default('_') }};
```

**Nginx config destination — must use `service_name` so each app gets its own file:**
```yaml
# In the Ansible template task:
dest: /etc/nginx/sites-available/{{ service_name }}
```

### 3. `deployment/templates/supervisor.conf.j2` — required patterns

The supervisor template must use `{{ gunicorn_bind }}`, not a hardcoded port:

```ini
# CORRECT
command={{ venv_dir }}/bin/gunicorn -w {{ gunicorn_workers }} -b {{ gunicorn_bind }} ...

# WRONG
command={{ venv_dir }}/bin/gunicorn -w 4 -b 127.0.0.1:8000 ...
```

**Supervisor config destination — must use `service_name`:**
```yaml
dest: /etc/supervisor/conf.d/{{ service_name }}.conf
```

### 4. Deployment playbook safety rules

The new app's `setup.yml` and `update.yml` must **not** delete or overwrite other
apps' nginx/supervisor configs. Specifically:

- **OK**: Remove `/etc/nginx/sites-enabled/default` (nginx default site — safe to remove)
- **NOT OK**: Remove or truncate all files in `/etc/nginx/sites-available/` or
  `/etc/supervisor/conf.d/` — this would kill the rampe app
- The update playbook should only touch `sites-available/{{ service_name }}` and
  `conf.d/{{ service_name }}.conf` — files named after its own app

---

## Step-by-step deployment on the shared server

### Before you start

- [ ] DNS: Create an A record for `yourapp.yourdomain.com` pointing at the
      server's public IP
- [ ] Port: Confirm the port you've chosen (e.g., 8001) is not in use:
      `ssh ubuntu@<server-ip> 'ss -tlnp | grep 8001'` — should return nothing
- [ ] Git: New app repo is pushed and accessible

### Deploy the new app

```bash
cd your-app-repo/deployment

# 1. Create and encrypt your vault
cp group_vars/vault.yml.example group_vars/vault.yml
# Edit vault.yml with your unique values (app_name, server_name, gunicorn_port, etc.)
ansible-vault encrypt group_vars/vault.yml --vault-password-file ~/.vault_pass

# 2. Point your inventory at the SAME server as rampe
#    The existing server's IP is in rampe's deployment/inventories/

# 3. Run setup-server.yml ONLY if the server itself is brand new.
#    If rampe is already running there, SKIP this step — the server is ready.
# ansible-playbook playbooks/setup-server.yml --vault-password-file ~/.vault_pass

# 4. Deploy the new app
ansible-playbook playbooks/setup.yml --vault-password-file ~/.vault_pass
```

`setup.yml` will:
- Create the new app's user (`yourapp_runtime`), group, and directories
- Clone the git repo into `/opt/yourapp`
- Install Python dependencies in `/opt/yourapp/.venv`
- Write `/etc/nginx/sites-available/yourapp` (FQDN-routed vhost)
- Write `/etc/supervisor/conf.d/yourapp.conf`
- Run certbot for `yourapp.yourdomain.com` (separate cert from rampe's)
- Start gunicorn on `127.0.0.1:8001`
- Verify nginx config and reload (`nginx -t && systemctl reload nginx`)

The reload is safe — nginx reloads configs for ALL vhosts atomically, so
`rampe.ipix.io` stays online throughout.

### Verify both apps are running

```bash
ssh ubuntu@<server-ip>

# Both supervisor processes should show RUNNING
supervisorctl status

# Both nginx vhosts should be enabled
ls -la /etc/nginx/sites-enabled/

# Both apps should be listening on their ports
ss -tlnp | grep '800'

# Test each app responds
curl -k https://rampe.ipix.io/login
curl -k https://yourapp.yourdomain.com/login
```

---

## Ongoing updates

To update the new app after this initial deployment, run `update.yml` from the
new app's repo. It will:

1. Pull the latest code
2. Re-render the nginx and supervisor configs from the templates
3. Restart nginx (safe — atomic reload, other apps unaffected)
4. Restart the new app's supervisor process only

The rampe app is never affected by running a different app's `update.yml`.

---

## Troubleshooting

**nginx fails to reload after deployment:**
```bash
nginx -t   # shows which config file has the syntax error
# Most common cause: rate-limit zone names not namespaced — two apps defining
# zone=login_limit collide. Ensure zones use {{ app_name }}_login_limit.
```

**Port conflict — gunicorn won't start:**
```bash
ss -tlnp | grep 8001   # check what is using the port
# Change gunicorn_port in vault.yml, re-encrypt, re-run setup.yml
```

**SSL cert fails (certbot error):**
- DNS must be fully propagated before setup.yml runs certbot
- Verify: `dig yourapp.yourdomain.com` resolves to the server's public IP
- If it fails, run separately: `ansible-playbook playbooks/setup-ssl.yml --vault-password-file ~/.vault_pass`

**One app works, the other returns nginx 404 / default page:**
```bash
ls /etc/nginx/sites-enabled/   # both vhost symlinks must be present
# If missing: ln -s /etc/nginx/sites-available/yourapp /etc/nginx/sites-enabled/yourapp
# Then: systemctl reload nginx
```

