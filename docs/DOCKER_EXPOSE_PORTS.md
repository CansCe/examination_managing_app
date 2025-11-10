# How to Expose Docker Containers to Public Internet

This guide explains how to make your Docker containers accessible from the internet.

## Option 1: Direct Port Exposure (Simple, Less Secure)

### Update docker-compose.yml

Use `0.0.0.0:port:port` to bind to all network interfaces:

```yaml
services:
  api:
    ports:
      - "0.0.0.0:3000:3000"  # Accessible from internet on port 3000
  chat:
    ports:
      - "0.0.0.0:3001:3001"  # Accessible from internet on port 3001
```

### Configure Firewall

```bash
# Allow ports 3000 and 3001
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp
sudo ufw enable
```

### Access Your Services

- **API:** `http://YOUR_SERVER_IP:3000`
- **Chat:** `http://YOUR_SERVER_IP:3001`

### Update Environment Variables

**backend-api/.env:**
```env
ALLOWED_ORIGINS=http://YOUR_SERVER_IP:3000,http://exam-app-api.duckdns.org
```

**backend-chat/.env:**
```env
ALLOWED_ORIGINS=http://YOUR_SERVER_IP:3001,http://backend-chat.duckdns.org
```

### Pros and Cons

**Pros:**
- Simple setup
- Direct access
- No reverse proxy needed

**Cons:**
- Less secure (exposes containers directly)
- No SSL/HTTPS (unless configured in containers)
- Harder to manage multiple domains
- Ports must be opened in firewall

---

## Option 2: Nginx Reverse Proxy (Recommended for Production)

### Use docker-compose.production.yml

```yaml
services:
  api:
    expose:
      - "3000"  # Internal only
  chat:
    expose:
      - "3001"  # Internal only
```

### Install and Configure Nginx

```bash
# Install Nginx
sudo apt install nginx -y

# Copy Nginx configs
sudo cp nginx/exam-app-api.duckdns.org.conf /etc/nginx/sites-available/
sudo cp nginx/backend-chat.duckdns.org.conf /etc/nginx/sites-available/

# Enable sites
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### Configure Firewall

```bash
# Only allow ports 80 and 443 (not 3000/3001)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### Setup SSL

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d exam-app-api.duckdns.org
sudo certbot --nginx -d backend-chat.duckdns.org
```

### Access Your Services

- **API:** `https://exam-app-api.duckdns.org`
- **Chat:** `https://backend-chat.duckdns.org`

### Pros and Cons

**Pros:**
- More secure (containers not directly exposed)
- SSL/HTTPS support
- Domain name routing
- Better for production
- Single entry point (ports 80/443)

**Cons:**
- More complex setup
- Requires Nginx configuration
- Requires DNS setup

---

## Quick Comparison

| Method | Security | SSL | Setup | Best For |
|--------|----------|-----|-------|----------|
| **Direct Ports** | Less secure | Manual | Simple | Development/Testing |
| **Nginx Proxy** | More secure | Easy (Certbot) | Complex | Production |

---

## Current Configuration

### docker-compose.yml (Direct Port Exposure)

Already configured with `0.0.0.0:port:port`:
- API: Accessible on `http://YOUR_SERVER_IP:3000`
- Chat: Accessible on `http://YOUR_SERVER_IP:3001`

### docker-compose.production.yml (Nginx Proxy)

Configured with `expose` (internal only):
- API: Accessible via Nginx on `https://exam-app-api.duckdns.org`
- Chat: Accessible via Nginx on `https://backend-chat.duckdns.org`

---

## Which Method to Use?

### Use Direct Port Exposure If:
- Testing/Development
- Quick setup needed
- Don't need SSL/HTTPS
- Using IP address instead of domain

### Use Nginx Reverse Proxy If:
- Production deployment
- Need SSL/HTTPS
- Using domain names
- Want better security
- Need multiple domains

---

## Quick Start

### Direct Port Exposure

```bash
# 1. Update docker-compose.yml (already done)
# 2. Start containers
docker-compose up -d

# 3. Configure firewall
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp

# 4. Access services
curl http://YOUR_SERVER_IP:3000/health
curl http://YOUR_SERVER_IP:3001/health
```

### Nginx Reverse Proxy

```bash
# 1. Use production compose
docker-compose -f docker-compose.production.yml up -d

# 2. Install and configure Nginx
sudo apt install nginx -y
sudo cp nginx/*.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 3. Configure firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 4. Setup SSL
sudo certbot --nginx -d exam-app-api.duckdns.org
sudo certbot --nginx -d backend-chat.duckdns.org

# 5. Access services
curl https://exam-app-api.duckdns.org/health
curl https://backend-chat.duckdns.org/health
```

---

## Troubleshooting

### Ports Not Accessible

**Check if containers are running:**
```bash
docker ps
docker-compose logs api
docker-compose logs chat
```

**Check if ports are bound:**
```bash
sudo netstat -tulpn | grep -E '3000|3001'
```

**Check firewall:**
```bash
sudo ufw status
```

### Connection Refused

**Check if service is listening:**
```bash
curl http://localhost:3000/health
curl http://localhost:3001/health
```

**Check if port is accessible from server:**
```bash
curl http://YOUR_SERVER_IP:3000/health
```

### CORS Errors

**Update ALLOWED_ORIGINS in .env files:**
```env
ALLOWED_ORIGINS=http://YOUR_SERVER_IP:3000,http://YOUR_SERVER_IP:3001
```

**Restart containers:**
```bash
docker-compose restart
```

---

## Summary

### Direct Port Exposure (Current docker-compose.yml)
- ✅ Already configured with `0.0.0.0:port:port`
- ✅ Simple setup
- ✅ Accessible on `http://YOUR_SERVER_IP:3000` and `http://YOUR_SERVER_IP:3001`
- ⚠️ Less secure
- ⚠️ No SSL by default

### Nginx Reverse Proxy (docker-compose.production.yml)
- ✅ More secure
- ✅ SSL/HTTPS support
- ✅ Domain name routing
- ✅ Better for production
- ⚠️ More complex setup

**Choose based on your needs:**
- **Development/Testing:** Use direct port exposure
- **Production:** Use Nginx reverse proxy

