# Quick Guide: Make Docker Containers Accessible via Public URL

## The Problem

Docker containers are only accessible on `localhost` by default. To make them accessible via public URLs like:
- `https://exam-app-api.duckdns.org`
- `https://backend-chat.duckdns.org`

You need to use **Nginx reverse proxy**.

## Quick Solution

### Step 1: Update Docker Compose

Change `ports` to `expose` in `docker-compose.yml`:

```yaml
services:
  api:
    expose:
      - "3000"  # Internal only
  chat:
    expose:
      - "3001"  # Internal only
```

Or use `docker-compose.production.yml` which already has this configuration.

### Step 2: Install Nginx

```bash
sudo apt install nginx -y
sudo systemctl start nginx
```

### Step 3: Configure Nginx

**Create `/etc/nginx/sites-available/exam-app-api.duckdns.org`:**
```nginx
server {
    listen 80;
    server_name exam-app-api.duckdns.org;
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Create `/etc/nginx/sites-available/backend-chat.duckdns.org`:**
```nginx
server {
    listen 80;
    server_name backend-chat.duckdns.org;
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

**Enable sites:**
```bash
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 4: Configure Firewall

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### Step 5: Update DNS

Update DuckDNS to point to your server IP:
```bash
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=$(curl -s ifconfig.me)"
```

### Step 6: Update Environment Variables

**backend-api/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

**backend-chat/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

### Step 7: Setup SSL

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d exam-app-api.duckdns.org
sudo certbot --nginx -d backend-chat.duckdns.org
```

### Step 8: Restart Containers

```bash
docker-compose restart
```

## Test

```bash
# Test from your local machine
curl https://exam-app-api.duckdns.org/health
curl https://backend-chat.duckdns.org/health
```

## Architecture

```
Internet → Your Server (ports 80/443) → Nginx → Docker Containers (ports 3000/3001 internal)
```

## Key Points

1. ✅ Use `expose` instead of `ports` in Docker Compose
2. ✅ Install Nginx as reverse proxy
3. ✅ Configure Nginx to proxy domains to containers
4. ✅ Open ports 80/443 on firewall
5. ✅ Update DNS to point to server IP
6. ✅ Update ALLOWED_ORIGINS in .env files
7. ✅ Setup SSL certificates

## Full Guide

For detailed instructions, see [DOCKER_EXPOSE_PUBLIC_URL.md](DOCKER_EXPOSE_PUBLIC_URL.md).

