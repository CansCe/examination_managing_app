# Docker Deployment on Your Own Server

This guide explains how to deploy your Exam Management App using Docker on your own server (dedicated server, VPS, or hardware).

**Want to expose containers to the internet?** See [DOCKER_EXPOSE_PORTS.md](DOCKER_EXPOSE_PORTS.md) for how to expose ports.

## Understanding: Docker vs Dedicated Server

**Important:** Docker doesn't host servers - it runs ON servers.

- **Dedicated Server** = The physical/virtual server (hardware or VPS)
- **Docker** = Containerization platform that runs ON the server
- **Your App** = Runs inside Docker containers ON the server

## Architecture

```
Your Dedicated Server/Hardware
├── Operating System (Ubuntu/Debian)
├── Docker Engine
├── Docker Compose
└── Your App Containers
    ├── API Container (backend-api)
    └── Chat Container (backend-chat)
```

---

## Option 1: Deploy on Your Own Hardware

If you have your own physical server or computer, you can install Docker and deploy your app.

### Prerequisites

- A computer/server running Linux (Ubuntu 20.04+ recommended)
- Internet connection
- Root/sudo access
- Ports 80, 443 accessible (for Nginx)
- Static IP address or dynamic DNS (DuckDNS)

### Step 1: Install Docker on Your Server

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

# Log out and log back in for group changes to take effect
exit
```

### Step 2: Setup Dynamic DNS (If Using Dynamic IP)

If your server has a dynamic IP address, use DuckDNS:

```bash
# Install DuckDNS updater (optional, for dynamic IP)
# Or manually update DuckDNS when IP changes
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=$(curl -s ifconfig.me)"
```

### Step 3: Configure Firewall

```bash
# Install UFW (if not installed)
sudo apt install ufw -y

# Allow SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### Step 4: Deploy Your App

Follow the same steps as cloud deployment:

1. Clone your repository
2. Create `.env` files
3. Install Nginx
4. Configure Nginx reverse proxy
5. Start Docker containers
6. Setup SSL certificates

See `SERVER_DEPLOYMENT_WITH_DOMAINS.md` for detailed steps.

---

## Option 2: Deploy on Rented Dedicated Server

If you rent a dedicated server from a provider, the process is the same as cloud VPS:

### Providers Offering Dedicated Servers

1. **Hetzner Dedicated** - https://www.hetzner.com/dedicated-rootserver
2. **OVH** - https://www.ovh.com
3. **Online.net** - https://www.online.net
4. **SoYouStart** - https://www.soyoustart.com

### Step 1: Order Dedicated Server

1. Choose a provider
2. Select server specifications:
   - **Minimum:** 4GB RAM, 2 CPU cores
   - **Recommended:** 8GB RAM, 4 CPU cores
3. Choose operating system: Ubuntu 22.04 LTS
4. Complete order

### Step 2: Access Your Server

```bash
# SSH into your dedicated server
ssh root@YOUR_SERVER_IP

# Or if using a non-root user
ssh username@YOUR_SERVER_IP
```

### Step 3: Install Docker

```bash
# Install Docker (same as Option 1)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Step 4: Deploy Your App

Follow `SERVER_DEPLOYMENT_WITH_DOMAINS.md` for complete deployment instructions.

---

## Option 3: Docker on Cloud VPS (Recommended)

This is what we've been recommending - it's essentially the same as a dedicated server but in the cloud:

- **DigitalOcean Droplet** = Virtual dedicated server
- **Vultr Instance** = Virtual dedicated server
- **AWS EC2** = Virtual dedicated server

All of these run Docker the same way as a physical dedicated server.

---

## Comparison: Dedicated Server vs Cloud VPS

### Physical Dedicated Server

**Pros:**
- Full control over hardware
- No resource sharing
- Can be cost-effective for high-performance needs
- Good for specific compliance requirements

**Cons:**
- Higher upfront cost
- Requires hardware maintenance
- Limited scalability
- Need to manage hardware failures
- Usually requires colocation or data center

### Cloud VPS (Virtual Dedicated Server)

**Pros:**
- Easy to set up and scale
- No hardware maintenance
- Pay-as-you-go pricing
- Automatic backups (usually)
- Multiple data centers
- Easy to upgrade/downgrade

**Cons:**
- Shared resources (usually)
- Less control over hardware
- Ongoing monthly costs

### Docker Deployment

**Same on both!** Docker works exactly the same way whether you're on:
- Physical dedicated server
- Cloud VPS
- Your own computer
- Raspberry Pi

---

## Docker Deployment Steps (Any Server Type)

### 1. Install Docker on Server

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. Clone Your Repository

```bash
# Clone repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app
```

### 3. Create Environment Files

```bash
# Create .env files
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env

# Edit with your credentials
nano backend-api/.env
nano backend-chat/.env
```

### 4. Install Nginx (Reverse Proxy)

```bash
# Install Nginx
sudo apt install nginx -y

# Copy Nginx configurations
sudo cp nginx/exam-app-api.duckdns.org.conf /etc/nginx/sites-available/
sudo cp nginx/backend-chat.duckdns.org.conf /etc/nginx/sites-available/

# Enable sites
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### 5. Start Docker Containers

```bash
# For production, use docker-compose.production.yml
docker-compose -f docker-compose.production.yml up -d --build

# Or modify docker-compose.yml to use 'expose' instead of 'ports'
# Then use:
docker-compose up -d --build

# Check status
docker ps
docker-compose logs -f
```

### 6. Setup SSL Certificates

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Get SSL certificates
sudo certbot --nginx -d exam-app-api.duckdns.org
sudo certbot --nginx -d backend-chat.duckdns.org
```

### 7. Update Environment Variables

Update `.env` files to use HTTPS:

**backend-api/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

**backend-chat/.env:**
```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
```

### 8. Restart Containers

```bash
docker-compose restart
```

---

## Docker Compose Configuration

### For Production (with Nginx)

Use `docker-compose.production.yml` which uses `expose` instead of `ports`:

```yaml
services:
  api:
    expose:
      - "3000"  # Internal only, Nginx proxies from port 80/443
  chat:
    expose:
      - "3001"  # Internal only, Nginx proxies from port 80/443
```

### For Local Development

Use `docker-compose.yml` which uses `ports`:

```yaml
services:
  api:
    ports:
      - "3000:3000"  # Exposed to host
  chat:
    ports:
      - "3001:3001"  # Exposed to host
```

---

## Benefits of Docker on Dedicated Server

1. **Isolation:** Each service runs in its own container
2. **Easy Deployment:** Deploy with a single command
3. **Scalability:** Easy to scale containers up/down
4. **Portability:** Same containers work on any server
5. **Resource Management:** Docker manages resources efficiently
6. **Easy Updates:** Update containers without affecting the server
7. **Rollback:** Easy to rollback to previous versions

---

## Monitoring and Maintenance

### Check Container Status

```bash
# List running containers
docker ps

# View logs
docker-compose logs -f

# Check resource usage
docker stats
```

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

# Backup Nginx configs
sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx/sites-available/
```

### Restart Services

```bash
# Restart Docker containers
docker-compose restart

# Restart Nginx
sudo systemctl restart nginx

# Restart Docker daemon (if needed)
sudo systemctl restart docker
```

---

## Troubleshooting

### Containers Not Starting

```bash
# Check logs
docker-compose logs api
docker-compose logs chat

# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker
```

### Port Conflicts

```bash
# Check what's using ports
sudo netstat -tulpn | grep -E '3000|3001|80|443'

# Stop conflicting services
sudo systemctl stop apache2  # If Apache is running
sudo systemctl stop nginx    # If you need to stop Nginx temporarily
```

### Docker Permissions

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in
exit
```

### Network Issues

```bash
# Check Docker network
docker network ls
docker network inspect exam-management-network

# Recreate network
docker network prune
docker-compose up -d
```

---

## Security Considerations

1. **Firewall:** Configure UFW or iptables to only allow necessary ports
2. **SSH Keys:** Use SSH keys instead of passwords
3. **Regular Updates:** Keep Docker and system updated
4. **.env Files:** Never commit .env files to git
5. **SSL Certificates:** Use HTTPS with Let's Encrypt
6. **Container Isolation:** Containers are isolated by default
7. **Resource Limits:** Set resource limits for containers (optional)

---

## Cost Comparison

### Physical Dedicated Server

- **Hardware Cost:** $500-2000+ (one-time)
- **Data Center/Colocation:** $50-200/month
- **Maintenance:** Your time
- **Total:** High upfront cost + ongoing costs

### Cloud VPS (Virtual Dedicated)

- **Monthly Cost:** $9-24/month
- **No Hardware:** No upfront cost
- **Maintenance:** Minimal (provider handles it)
- **Total:** Low ongoing cost

### Recommendation

For most users, **cloud VPS is better** because:
- Lower cost
- Easier to manage
- No hardware maintenance
- Easy to scale
- Same Docker deployment process

---

## Summary

**Docker Deployment is the Same on:**
- ✅ Physical dedicated server
- ✅ Cloud VPS (DigitalOcean, Vultr, etc.)
- ✅ Your own computer
- ✅ Raspberry Pi
- ✅ Any Linux server

**Key Points:**
1. Docker runs ON servers, not the other way around
2. Install Docker on your server (any type)
3. Use Docker Compose to deploy your app
4. Use Nginx as reverse proxy
5. Setup SSL certificates
6. Your app runs in Docker containers

**Recommended Approach:**
- Start with cloud VPS (DigitalOcean, Vultr) - easiest and most cost-effective
- Use Docker for deployment - same process on any server
- Follow `SERVER_DEPLOYMENT_WITH_DOMAINS.md` for detailed steps

---


