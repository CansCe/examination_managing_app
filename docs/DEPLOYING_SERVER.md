# Complete Server Deployment Guide

Complete step-by-step guide for deploying your Exam Management App to a server and troubleshooting connection issues.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step-by-Step Deployment](#step-by-step-deployment)
3. [Troubleshooting Connection Timeout](#troubleshooting-connection-timeout)
4. [Fixing Docker Configuration](#fixing-docker-configuration)
5. [Fixing CORS and Socket.io](#fixing-cors-and-socketio)
6. [Verifying Deployment](#verifying-deployment)
7. [Diagnostic Scripts](#diagnostic-scripts)

---

## Prerequisites

- Server with Ubuntu 22.04 LTS (AWS EC2, DigitalOcean, Vultr, etc.)
- Root/sudo access to the server
- DuckDNS domains configured
- MongoDB Atlas account or MongoDB instance
- SSH access to your server
- Git repository with your code

---

## Step-by-Step Deployment

### Step 1: Connect to Your Server

```bash
# SSH into your server
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP

# Or if using password authentication
ssh ubuntu@YOUR_SERVER_IP
```

### Step 2: Install Docker

```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose -y

# Logout and login again for group changes
exit
# SSH back in
ssh -i your-key.pem ubuntu@YOUR_SERVER_IP

# Verify installation
docker --version
docker-compose --version
```

### Step 3: Clone Your Repository

```bash
# Install Git
sudo apt install git -y

# Clone repository (use Personal Access Token if needed)
git clone https://github.com/CansCe/exam_management_app.git
cd exam_management_app

# Or if using SSH
git clone git@github.com:CansCe/exam_management_app.git
cd exam_management_app
```

### Step 4: Configure Environment Variables

```bash
# Create .env files
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env

# Edit API .env file
nano backend-api/.env
```

**Update `backend-api/.env`:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org,http://localhost:8080
```

**Update `backend-chat/.env`:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org,http://localhost:8080
DEFAULT_ADMIN_ID=optional-admin-objectid
```

**Save and exit:** `Ctrl+X`, then `Y`, then `Enter`

### Step 5: Update Docker Compose Configuration

**IMPORTANT:** Update `docker-compose.yml` to use `ports` instead of `expose`:

```yaml
version: '3.8'

services:
  # Main API Service (MongoDB)
  api:
    build:
      context: ./backend-api
      dockerfile: Dockerfile
    container_name: exam-management-api
    # IMPORTANT: Use 'ports' not 'expose' so Nginx can access from host
    ports:
      - "127.0.0.1:3000:3000"  # Bind to localhost only (secure)
    env_file:
      - ./backend-api/.env
    environment:
      - PORT=3000
      - NODE_ENV=${NODE_ENV:-production}
      - MONGODB_URI=${MONGODB_URI:-}
      - MONGODB_DB=${MONGODB_DB:-exam_management}
      - ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-}
    restart: unless-stopped
    networks:
      - exam-management-network
    healthcheck:
      # FIX: Use localhost, not external domain
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Chat Service (MongoDB + Socket.io)
  chat:
    build:
      context: ./backend-chat
      dockerfile: Dockerfile
    container_name: exam-management-chat
    # IMPORTANT: Use 'ports' not 'expose' so Nginx can access from host
    ports:
      - "127.0.0.1:3001:3001"  # Bind to localhost only (secure)
    env_file:
      - ./backend-chat/.env
    environment:
      - PORT=3001
      - NODE_ENV=${NODE_ENV:-production}
      - MONGODB_URI=${MONGODB_URI:-}
      - MONGODB_DB=${MONGODB_DB:-exam_management}
      - ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-}
      - DEFAULT_ADMIN_ID=${DEFAULT_ADMIN_ID:-}
    restart: unless-stopped
    networks:
      - exam-management-network
    healthcheck:
      # FIX: Use localhost, not external domain
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  exam-management-network:
    driver: bridge
```

**Key Changes:**
- Changed `expose` to `ports` with `127.0.0.1:3000:3000` and `127.0.0.1:3001:3001`
- Fixed health checks to use `localhost` instead of external domains
- Increased `timeout` to 10s and `start_period` to 40s

### Step 6: Get Your Server IP and Update DuckDNS

```bash
# Get your server's public IP
curl -4 ifconfig.me

# Update DuckDNS to point to SERVER IP (not laptop IP)
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_DUCKDNS_TOKEN&ip=YOUR_SERVER_IP"

# Replace:
# - YOUR_DUCKDNS_TOKEN: Your DuckDNS token
# - YOUR_SERVER_IP: Your server's public IP
```

### Step 7: Deploy Docker Containers

```bash
# Make sure you're in the project directory
cd ~/exam_management_app

# Stop any running containers
docker-compose down

# Build and start containers
docker-compose up -d --build

# Check status
docker ps

# Check logs
docker-compose logs -f
```

### Step 8: Verify Containers Are Running

```bash
# Check container status
docker ps

# Test containers from host
curl http://localhost:3000/health
curl http://localhost:3001/health

# Both should return JSON responses
```

### Step 9: Install and Configure Nginx

```bash
# Install Nginx
sudo apt install nginx -y

# Create API config
sudo nano /etc/nginx/sites-available/exam-app-api.duckdns.org
```

**Paste this content:**
```nginx
server {
    listen 80;
    server_name exam-app-api.duckdns.org;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Save and exit:** `Ctrl+X`, then `Y`, then `Enter`

```bash
# Create Chat config
sudo nano /etc/nginx/sites-available/backend-chat.duckdns.org
```

**Paste this content:**
```nginx
server {
    listen 80;
    server_name backend-chat.duckdns.org;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support for Socket.io
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

**Save and exit:** `Ctrl+X`, then `Y`, then `Enter`

```bash
# Enable sites
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/

# Remove default site (optional)
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# If test passes, reload Nginx
sudo systemctl reload nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Check Nginx status
sudo systemctl status nginx
```

### Step 10: Configure Firewall

#### For UFW (Ubuntu Firewall)

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow SSH (if not already allowed)
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

#### For AWS Security Groups

1. Go to AWS Console: https://console.aws.amazon.com/ec2
2. Click "Instances" → Select your instance
3. Click "Security" tab → Click security group name
4. Click "Edit inbound rules"
5. Add rules:
   - Type: HTTP, Port: 80, Source: 0.0.0.0/0
   - Type: HTTPS, Port: 443, Source: 0.0.0.0/0
   - Type: SSH, Port: 22, Source: Your IP (or 0.0.0.0/0 for testing)
6. Click "Save rules"

### Step 11: Verify DNS Resolution

```bash
# Wait 5-10 minutes for DNS propagation, then check
nslookup exam-app-api.duckdns.org
nslookup backend-chat.duckdns.org

# Should show your SERVER IP, not your laptop IP
# Compare with:
curl -4 ifconfig.me
```

### Step 12: Test Your Deployment

#### From Server

```bash
# Test API
curl http://localhost:3000/health
curl http://exam-app-api.duckdns.org/health

# Test Chat
curl http://localhost:3001/health
curl http://backend-chat.duckdns.org/health
```

#### From Your Local Machine

```bash
# Test API
curl http://exam-app-api.duckdns.org/health

# Test Chat
curl http://backend-chat.duckdns.org/health

# Or test in browser
# http://exam-app-api.duckdns.org
# http://backend-chat.duckdns.org
```

---

## Troubleshooting Connection Timeout

### Issue: "ERR_CONNECTION_TIMED_OUT" or "This site can't be reached"

This means the server is not accessible from the internet. Check these in order:

### 1. Verify DNS Resolution

**From your local machine:**
```bash
nslookup exam-app-api.duckdns.org
```

**Should show your SERVER IP, not your laptop IP.**

**If DNS is wrong:**
```bash
# Get server IP
curl -4 ifconfig.me

# Update DuckDNS
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=YOUR_SERVER_IP"

# Wait 5-10 minutes
```

### 2. Check Port 80 is Listening

**On your server:**
```bash
# Check if Nginx is listening on port 80
sudo netstat -tlnp | grep :80
# Should show: tcp 0.0.0.0:80 LISTEN nginx

# Or use ss command
sudo ss -tlnp | grep :80

# Check if Nginx is running
sudo systemctl status nginx
```

**If Nginx is not listening:**
```bash
# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

### 3. Check Firewall (UFW)

**On your server:**
```bash
# Check firewall status
sudo ufw status

# If port 80 is not allowed, add it
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall if not enabled
sudo ufw enable

# Verify
sudo ufw status
# Should show: 80/tcp ALLOW Anywhere
```

### 4. Check AWS Security Groups (if using AWS)

1. Go to AWS Console: https://console.aws.amazon.com/ec2
2. Click "Instances" → Select your instance
3. Click "Security" tab → Click security group name
4. Click "Edit inbound rules"
5. **Ensure you have:**
   - Type: HTTP, Port: 80, Source: 0.0.0.0/0
   - Type: HTTPS, Port: 443, Source: 0.0.0.0/0
6. Click "Save rules"

### 5. Test Server Accessibility

**From your server:**
```bash
# Test if you can reach the server from itself
curl http://localhost
curl http://127.0.0.1

# Test with server's public IP
curl http://YOUR_SERVER_IP
```

**From your local machine:**
```bash
# Test if you can reach the server by IP
curl http://YOUR_SERVER_IP

# If this fails, the server is not accessible from internet
# This could be:
# - Firewall blocking (AWS Security Group or UFW)
# - Server behind NAT/firewall
# - ISP blocking incoming connections
```

### 6. Check Nginx Configuration

**On your server:**
```bash
# Test Nginx configuration
sudo nginx -t

# Check Nginx error logs
sudo tail -20 /var/log/nginx/error.log

# Check if sites are enabled
ls -la /etc/nginx/sites-enabled/

# Check Nginx config files
cat /etc/nginx/sites-available/exam-app-api.duckdns.org
cat /etc/nginx/sites-available/backend-chat.duckdns.org
```

### 7. Verify Docker Containers Are Running

**On your server:**
```bash
# Check container status
docker ps

# Check if containers are accessible
curl http://localhost:3000/health
curl http://localhost:3001/health

# Check container logs
docker-compose logs api
docker-compose logs chat
```

### 8. Test from External Service

Use an external tool to test if your server is reachable:

1. Go to: https://www.yougetsignal.com/tools/open-ports/
2. Enter your server IP
3. Enter port 80
4. Click "Check"

**If port 80 is closed:**
- AWS Security Group is blocking it, OR
- UFW firewall is blocking it, OR
- Server is behind a NAT/firewall

---

## Fixing Docker Configuration

### Problem: Containers Show as "Unhealthy"

**Symptoms:**
- Containers show as "unhealthy" in `docker ps`
- Health checks fail
- Services not accessible

**Fix:**

1. **Update `docker-compose.yml` health checks:**
   - Change from external domains to `localhost`
   - Increase `timeout` to 10s
   - Increase `start_period` to 40s

2. **Use `ports` instead of `expose`:**
   - Change `expose: - "3000"` to `ports: - "127.0.0.1:3000:3000"`
   - This allows Nginx to access containers from host

3. **Restart containers:**
   ```bash
   docker-compose down
   docker-compose up -d --build
   ```

### Problem: Containers Not Accessible from Host

**Symptoms:**
- `curl http://localhost:3000/health` fails
- Nginx returns "502 Bad Gateway"
- Containers are running but not accessible

**Fix:**

1. **Check `docker-compose.yml` uses `ports`:**
   ```yaml
   ports:
     - "127.0.0.1:3000:3000"
   ```

2. **Verify containers are running:**
   ```bash
   docker ps
   ```

3. **Check if ports are listening:**
   ```bash
   sudo netstat -tlnp | grep -E '3000|3001'
   ```

4. **Restart containers:**
   ```bash
   docker-compose restart
   ```

---

## Fixing CORS and Socket.io

### Problem: Chat Service Only Accepting Localhost

**Symptoms:**
- Flutter app can't connect to chat service
- CORS errors in browser console
- Socket.io connection fails

**Fix:**

1. **Update `backend-chat/.env`:**
   ```env
   ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org,http://localhost:8080
   ```

2. **Update `backend-api/.env`:**
   ```env
   ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org,http://localhost:8080
   ```

3. **Verify Socket.io CORS configuration in `backend-chat/server.js`:**
   - Socket.io server should use the same `ALLOWED_ORIGINS`
   - CORS should allow your DuckDNS domains

4. **Restart containers:**
   ```bash
   docker-compose restart
   ```

### Problem: API Auto-Discovery Not Finding Server

**Symptoms:**
- Flutter app can't find API endpoint
- Auto-discovery falls back to localhost
- App can't connect to server

**Fix:**

1. **Verify `lib/services/api_discovery_service.dart` includes server URLs:**
   ```dart
   static final List<String> _defaultApiUrls = [
     'https://exam-app-api.duckdns.org',
     'http://exam-app-api.duckdns.org',
     'http://localhost:3000',
     'http://10.0.2.2:3000',
   ];
   
   static final List<String> _defaultChatUrls = [
     'https://backend-chat.duckdns.org',
     'http://backend-chat.duckdns.org',
     'http://localhost:3001',
     'http://10.0.2.2:3001',
   ];
   ```

2. **Verify server is accessible:**
   ```bash
   curl http://exam-app-api.duckdns.org/health
   curl http://backend-chat.duckdns.org/health
   ```

3. **Check Flutter app logs for discovery:**
   - App should try server URLs first
   - Should log which URL was found

---

## Verifying Deployment

### Complete Verification Checklist

- [ ] Docker containers are running (`docker ps`)
- [ ] Containers are healthy (not "unhealthy")
- [ ] Ports are accessible from host (`curl http://localhost:3000/health`)
- [ ] Nginx is running (`sudo systemctl status nginx`)
- [ ] Nginx is listening on port 80 (`sudo netstat -tlnp | grep :80`)
- [ ] Nginx configs are enabled (`ls /etc/nginx/sites-enabled/`)
- [ ] Firewall allows port 80 (`sudo ufw status`)
- [ ] AWS Security Group allows port 80 (if using AWS)
- [ ] DNS points to server IP (`nslookup exam-app-api.duckdns.org`)
- [ ] Server is accessible by IP (`curl http://YOUR_SERVER_IP`)
- [ ] Server is accessible by domain (`curl http://exam-app-api.duckdns.org`)
- [ ] API health endpoint works (`curl http://exam-app-api.duckdns.org/health`)
- [ ] Chat health endpoint works (`curl http://backend-chat.duckdns.org/health`)
- [ ] CORS allows server domains (check `.env` files)
- [ ] Socket.io CORS is configured (check `backend-chat/server.js`)

### Test from Flutter App

1. **Clear app data/cache**
2. **Restart app**
3. **Check logs for API discovery:**
   - Should see: "🔍 Starting API URL discovery..."
   - Should see: "✅ Found working API: https://exam-app-api.duckdns.org"
4. **Test API connection:**
   - Login should work
   - Data should load from server
5. **Test Chat connection:**
   - Chat should connect to server
   - Messages should send/receive

---

## Diagnostic Scripts

### Quick Diagnostic Script

Save as `diagnose.sh`:

```bash
#!/bin/bash
echo "=== Server IP ==="
SERVER_IP=$(curl -4 -s ifconfig.me)
echo "Public IP: $SERVER_IP"

echo -e "\n=== DNS Resolution ==="
echo "exam-app-api.duckdns.org:"
nslookup exam-app-api.duckdns.org | grep -A 2 "Name:" || echo "DNS lookup failed"

echo -e "\n=== Firewall (UFW) ==="
sudo ufw status

echo -e "\n=== Listening Ports ==="
echo "Port 80:"
sudo netstat -tlnp | grep :80 || echo "Port 80 NOT listening"
echo -e "\nPort 443:"
sudo netstat -tlnp | grep :443 || echo "Port 443 NOT listening"
echo -e "\nPort 3000:"
sudo netstat -tlnp | grep :3000 || echo "Port 3000 NOT listening"
echo -e "\nPort 3001:"
sudo netstat -tlnp | grep :3001 || echo "Port 3001 NOT listening"

echo -e "\n=== Nginx Status ==="
sudo systemctl status nginx --no-pager -l

echo -e "\n=== Nginx Configuration ==="
sudo nginx -t

echo -e "\n=== Docker Containers ==="
docker ps

echo -e "\n=== Container Health ==="
echo "API (localhost:3000):"
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo "FAILED"
echo -e "\nChat (localhost:3001):"
curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health || echo "FAILED"

echo -e "\n=== Test from Server ==="
echo "Testing http://$SERVER_IP:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$SERVER_IP || echo "FAILED - Server not accessible from itself"

echo -e "\n=== Test Domains ==="
echo "Testing http://exam-app-api.duckdns.org:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://exam-app-api.duckdns.org || echo "FAILED"

echo -e "\n=== Nginx Logs (Last 5 lines) ==="
sudo tail -5 /var/log/nginx/error.log

echo -e "\n=== Docker Logs (Last 10 lines) ==="
docker-compose logs --tail=10
```

**Make executable and run:**
```bash
chmod +x diagnose.sh
./diagnose.sh
```

### Test Connection Script

Save as `test-connection.sh`:

```bash
#!/bin/bash
echo "=== Testing Server Connectivity ==="

echo -e "\n1. Testing localhost:3000 (API):"
curl -s http://localhost:3000/health | head -5

echo -e "\n2. Testing localhost:3001 (Chat):"
curl -s http://localhost:3001/health | head -5

echo -e "\n3. Testing API domain:"
curl -s http://exam-app-api.duckdns.org/health | head -5

echo -e "\n4. Testing Chat domain:"
curl -s http://backend-chat.duckdns.org/health | head -5

echo -e "\n=== Testing from External ==="
echo "5. Testing server IP:"
SERVER_IP=$(curl -4 -s ifconfig.me)
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$SERVER_IP
```

**Make executable and run:**
```bash
chmod +x test-connection.sh
./test-connection.sh
```

---

## Common Issues and Solutions

### Issue 1: "Connection Refused" or "Connection Timeout"

**Causes:**
1. DNS pointing to wrong IP (laptop instead of server)
2. Firewall blocking port 80
3. AWS Security Group blocking port 80
4. Nginx not running
5. Containers not accessible from host

**Solution:**
1. Check DNS resolution
2. Check firewall (UFW and AWS Security Groups)
3. Verify Nginx is running
4. Verify containers are accessible from host
5. Check `docker-compose.yml` uses `ports` not `expose`

### Issue 2: "502 Bad Gateway"

**Causes:**
1. Containers not running
2. Containers not accessible from host (using `expose` instead of `ports`)
3. Wrong port in Nginx config
4. Containers crashed

**Solution:**
1. Check container status: `docker ps`
2. Check container logs: `docker-compose logs`
3. Verify `docker-compose.yml` uses `ports`
4. Test containers: `curl http://localhost:3000/health`

### Issue 3: "CORS Error" or "Chat Not Connecting"

**Causes:**
1. `ALLOWED_ORIGINS` doesn't include server domains
2. Socket.io CORS not configured
3. Wrong CORS configuration

**Solution:**
1. Update `.env` files with server domains
2. Verify Socket.io CORS configuration
3. Restart containers: `docker-compose restart`

### Issue 4: "DNS Resolution Failed"

**Causes:**
1. DNS not pointing to server IP
2. DNS propagation delay
3. Wrong DuckDNS configuration

**Solution:**
1. Update DuckDNS with server IP
2. Wait 5-10 minutes for propagation
3. Verify: `nslookup exam-app-api.duckdns.org`

### Issue 5: Containers Unhealthy

**Causes:**
1. MongoDB connection failed
2. Health check using wrong URL
3. Health check timeout too short

**Solution:**
1. Check MongoDB connection in logs
2. Fix health checks to use `localhost`
3. Increase `timeout` and `start_period` in `docker-compose.yml`

---

## Summary

### Key Points

1. **Use `ports` not `expose`** in `docker-compose.yml` so Nginx can access containers
2. **Fix health checks** to use `localhost` instead of external domains
3. **Configure CORS** to allow server domains in `.env` files
4. **Configure firewall** (UFW and AWS Security Groups) to allow port 80
5. **Update DuckDNS** to point to server IP (not laptop IP)
6. **Verify DNS** resolution before testing
7. **Test from server first**, then from external

### Quick Fix Checklist

- [ ] Update `docker-compose.yml` to use `ports`
- [ ] Fix health checks to use `localhost`
- [ ] Update `.env` files with server domains in `ALLOWED_ORIGINS`
- [ ] Update DuckDNS with server IP
- [ ] Configure firewall (UFW and AWS Security Groups)
- [ ] Verify Nginx is running and configured
- [ ] Restart containers: `docker-compose restart`
- [ ] Test from server: `curl http://exam-app-api.duckdns.org/health`
- [ ] Test from browser: `http://exam-app-api.duckdns.org`

---

## Additional Resources

- [AWS EC2 Deployment Guide](AWS_EC2_DEPLOYMENT.md)
- [Server Deployment with Domains](SERVER_DEPLOYMENT_WITH_DOMAINS.md)
- [Docker Expose Public URL](DOCKER_EXPOSE_PUBLIC_URL.md)
- [Server Providers Guide](SERVER_PROVIDERS_GUIDE.md)

> **Note:** All documentation files are located in the `docs/` folder. Links above use relative paths since all files are in the same directory.

---

## Support

If you're still experiencing issues:

1. Run the diagnostic script: `./diagnose.sh`
2. Check container logs: `docker-compose logs`
3. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
4. Verify DNS: `nslookup exam-app-api.duckdns.org`
5. Test from server: `curl http://exam-app-api.duckdns.org/health`

Share the outputs for further assistance.

