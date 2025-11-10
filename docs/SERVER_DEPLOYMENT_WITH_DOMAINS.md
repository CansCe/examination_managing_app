# Server Deployment Guide with DuckDNS Domains

Complete guide for deploying Docker containers to a server with domain names.

## Your Domains

- **Main API:** `http://exam-app-api.duckdns.org` (will be `https://` after SSL setup)
- **Backend Chat:** `http://backend-chat.duckdns.org` (will be `https://` after SSL setup)

**Important:** This guide is for deploying to a **cloud server** (VPS), not your laptop. If your DNS currently points to your laptop IP, see [LAPTOP_VS_SERVER_IP.md](LAPTOP_VS_SERVER_IP.md) for how to migrate to a proper server.

**Want to make containers accessible via public URL instead of localhost?** See [DOCKER_EXPOSE_PUBLIC_URL.md](DOCKER_EXPOSE_PUBLIC_URL.md) for detailed instructions.

## Prerequisites

- **Server** - See [SERVER_PROVIDERS_GUIDE.md](SERVER_PROVIDERS_GUIDE.md) for where to get a server
- Server with Docker and Docker Compose installed
- Root/sudo access to the server
- DuckDNS domains configured and pointing to your server IP
- MongoDB Atlas account or MongoDB instance
- Ports 80, 443, 3000, 3001 accessible

**Don't have a server yet?** See [SERVER_PROVIDERS_GUIDE.md](SERVER_PROVIDERS_GUIDE.md) for recommended providers and how to get started.

---

## Step 1: Server Setup

### 1.1 SSH into Your Server

```bash
ssh user@your-server-ip
```

### 1.2 Install Docker and Docker Compose

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### 1.3 Install Nginx (Reverse Proxy)

```bash
# Install Nginx
sudo apt install nginx -y

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify Nginx is running
sudo systemctl status nginx
```

### 1.4 Install Certbot (SSL Certificates)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y
```

---

## Step 2: Configure DuckDNS

### 2.1 Update DuckDNS IP (if needed)

If your server IP changes, update DuckDNS:

```bash
# Get your server's public IP
curl -4 ifconfig.me

# Update DuckDNS (replace YOUR_TOKEN and YOUR_DOMAIN)
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_DUCKDNS_TOKEN&ip="
```

### 2.2 Verify DNS Resolution

```bash
# Check if domains resolve to your server IP
nslookup exam-app-api.duckdns.org
nslookup backend-chat.duckdns.org
```

---

## Step 3: Clone and Configure Repository

### 3.1 Clone Repository

```bash
# Clone your repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app
```

### 3.2 Create .env Files

**backend-api/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=http://exam-app-api.duckdns.org,https://exam-app-api.duckdns.org,http://backend-chat.duckdns.org,https://backend-chat.duckdns.org
```

**backend-chat/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=http://exam-app-api.duckdns.org,https://exam-app-api.duckdns.org,http://backend-chat.duckdns.org,https://backend-chat.duckdns.org
DEFAULT_ADMIN_ID=optional-admin-objectid
```

**Create the files:**
```bash
# Copy examples
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env

# Edit with your credentials
nano backend-api/.env
nano backend-chat/.env
```

---

## Step 4: Update Docker Compose for Internal Network

### 4.1 Update docker-compose.yml

The containers should only expose ports internally (not to the host). Nginx will proxy to them.

**Update `docker-compose.yml`:**
```yaml
version: '3.8'

services:
  # Main API Service (MongoDB)
  api:
    build:
      context: ./backend-api
      dockerfile: Dockerfile
    container_name: exam-management-api
    # Don't expose ports to host - Nginx will proxy
    expose:
      - "3000"
    env_file:
      - ./backend-api/.env
    environment:
      - PORT=3000
      - NODE_ENV=production
    restart: unless-stopped
    networks:
      - exam-management-network
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s

  # Chat Service (MongoDB + Socket.io)
  chat:
    build:
      context: ./backend-chat
      dockerfile: Dockerfile
    container_name: exam-management-chat
    # Don't expose ports to host - Nginx will proxy
    expose:
      - "3001"
    env_file:
      - ./backend-chat/.env
    environment:
      - PORT=3001
      - NODE_ENV=production
    restart: unless-stopped
    networks:
      - exam-management-network
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s

networks:
  exam-management-network:
    driver: bridge
```

---

## Step 5: Configure Nginx Reverse Proxy

### 5.1 Create Nginx Configuration for API

**Create `/etc/nginx/sites-available/exam-app-api.duckdns.org`:**
```nginx
# API Service - exam-app-api.duckdns.org
server {
    listen 80;
    server_name exam-app-api.duckdns.org;

    # Logging
    access_log /var/log/nginx/exam-app-api-access.log;
    error_log /var/log/nginx/exam-app-api-error.log;

    # Proxy to Docker container
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 5.2 Create Nginx Configuration for Chat

**Create `/etc/nginx/sites-available/backend-chat.duckdns.org`:**
```nginx
# Chat Service - backend-chat.duckdns.org
server {
    listen 80;
    server_name backend-chat.duckdns.org;

    # Logging
    access_log /var/log/nginx/backend-chat-access.log;
    error_log /var/log/nginx/backend-chat-error.log;

    # Proxy to Docker container (Socket.io support)
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        
        # WebSocket support for Socket.io
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Socket.io specific settings
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts for long-lived connections
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

### 5.3 Enable Nginx Sites

```bash
# Create symbolic links
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/

# Remove default site (optional)
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

---

## Step 6: Start Docker Containers

### 6.1 Build and Start Containers

```bash
# Build and start containers
docker-compose up -d --build

# Check status
docker ps

# View logs
docker-compose logs -f
```

### 6.2 Verify Containers Are Running

```bash
# Check API health
curl http://localhost:3000/health

# Check Chat health
curl http://localhost:3001/health
```

---

## Step 7: Configure Firewall

### 7.1 Allow Required Ports

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

**Note:** Ports 3000 and 3001 are NOT exposed to the internet - only Nginx (ports 80/443) is accessible.

---

## Step 8: Setup SSL Certificates (HTTPS)

### 8.1 Obtain SSL Certificates

```bash
# Get SSL certificate for API domain
sudo certbot --nginx -d exam-app-api.duckdns.org

# Get SSL certificate for Chat domain
sudo certbot --nginx -d backend-chat.duckdns.org

# Follow the prompts:
# - Enter email address
# - Agree to terms
# - Choose whether to redirect HTTP to HTTPS (recommended: Yes)
```

### 8.2 Verify SSL Certificates

```bash
# Test API domain
curl https://exam-app-api.duckdns.org/health

# Test Chat domain
curl https://backend-chat.duckdns.org/health
```

### 8.3 Auto-Renewal Setup

Certbot automatically sets up auto-renewal. Verify:

```bash
# Test renewal
sudo certbot renew --dry-run

# Check renewal timer
sudo systemctl status certbot.timer
```

---

## Step 9: Update Environment Variables for HTTPS

### 9.1 Update .env Files

After SSL is set up, update `ALLOWED_ORIGINS` to use HTTPS:

**backend-api/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

**backend-chat/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

### 9.2 Restart Containers

```bash
# Restart containers to apply new environment variables
docker-compose restart
```

---

## Step 10: Update Flutter App Configuration

### 10.1 Update API Configuration

**Option 1: Build-time configuration (Recommended for production)**

```bash
# Build APK with domain URLs
flutter build apk --release \
  --dart-define=API_BASE_URL=https://exam-app-api.duckdns.org \
  --dart-define=CHAT_BASE_URL=https://backend-chat.duckdns.org

# Build App Bundle for Google Play
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://exam-app-api.duckdns.org \
  --dart-define=CHAT_BASE_URL=https://backend-chat.duckdns.org
```

**Option 2: Update `lib/config/api_config.dart`**

Add your domains to the auto-discovery list:

```dart
// In api_discovery_service.dart, add to _defaultApiUrls:
static const List<String> _defaultApiUrls = [
  'https://exam-app-api.duckdns.org',
  'http://exam-app-api.duckdns.org',
  // ... other URLs
];

static const List<String> _defaultChatUrls = [
  'https://backend-chat.duckdns.org',
  'http://backend-chat.duckdns.org',
  // ... other URLs
];
```

---

## Step 11: Verify Deployment

### 11.1 Test API Endpoints

```bash
# Test API health
curl https://exam-app-api.duckdns.org/health

# Test Chat health
curl https://backend-chat.duckdns.org/health
```

### 11.2 Test from Flutter App

1. Build and install the Flutter app on a device
2. Open the app
3. Verify it connects to the API
4. Test chat functionality

### 11.3 Check Logs

```bash
# Docker logs
docker-compose logs -f api
docker-compose logs -f chat

# Nginx logs
sudo tail -f /var/log/nginx/exam-app-api-access.log
sudo tail -f /var/log/nginx/backend-chat-access.log
```

---

## Troubleshooting

### Containers Not Starting

```bash
# Check logs
docker-compose logs api
docker-compose logs chat

# Check if ports are in use
sudo netstat -tulpn | grep -E '3000|3001'

# Restart containers
docker-compose restart
```

### Nginx Not Routing to Containers

```bash
# Test Nginx configuration
sudo nginx -t

# Check if containers are accessible from host
curl http://localhost:3000/health
curl http://localhost:3001/health

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### SSL Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew

# Check Nginx SSL configuration
sudo nginx -t
```

### DNS Not Resolving

```bash
# Check DNS resolution
nslookup exam-app-api.duckdns.org
nslookup backend-chat.duckdns.org

# Update DuckDNS IP if server IP changed
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip="
```

### CORS Errors

If you see CORS errors, verify `ALLOWED_ORIGINS` in `.env` files includes your domains:

```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

Then restart containers:
```bash
docker-compose restart
```

---

## Maintenance

### Update Containers

```bash
# Pull latest code
git pull

# Rebuild and restart
docker-compose up -d --build

# Check logs
docker-compose logs -f
```

### Backup

```bash
# Backup .env files
tar -czf env-backup-$(date +%Y%m%d).tar.gz backend-api/.env backend-chat/.env

# Backup Nginx configurations
sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx/sites-available/
```

### Monitor

```bash
# Monitor container resources
docker stats

# Monitor Nginx access
sudo tail -f /var/log/nginx/*-access.log

# Monitor container logs
docker-compose logs -f
```

---

## Security Checklist

- [ ] SSL certificates installed and auto-renewing
- [ ] Firewall configured (only ports 80, 443, 22 open)
- [ ] Containers not exposed directly to internet (only via Nginx)
- [ ] .env files not in Docker images
- [ ] Strong MongoDB credentials
- [ ] Regular backups
- [ ] Monitoring and logging enabled
- [ ] DuckDNS token secured

---

## Summary

Your deployment is now complete! 

**API Endpoint:** `https://exam-app-api.duckdns.org`  
**Chat Endpoint:** `https://backend-chat.duckdns.org`

**Next Steps:**
1. Update Flutter app with domain URLs
2. Build and distribute the app
3. Monitor logs and performance
4. Set up regular backups

For questions or issues, check the logs and troubleshooting section above.

