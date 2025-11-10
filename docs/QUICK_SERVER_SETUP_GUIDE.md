# Quick Guide: Host on a Server (Not Laptop)

## The Problem

Your DNS currently points to your **laptop IP** (117.5.56.77), which is not suitable for production because:
- ❌ Laptop IP changes when you reconnect
- ❌ Laptop must be on 24/7
- ❌ Home firewall blocks incoming connections
- ❌ Security risk

## The Solution

Deploy to a **cloud server** (VPS) with a static IP address.

---

## Quick Steps (5 minutes)

### Step 1: Get a Server

**Option A: AWS EC2 (Industry Standard) ⭐**
1. Go to https://aws.amazon.com
2. Sign up and launch an EC2 instance
3. Choose: Ubuntu 22.04 LTS, t3.medium ($30/month) or t3.micro (Free Tier)
4. Get your server IP
5. **See:** [AWS_EC2_DEPLOYMENT.md](AWS_EC2_DEPLOYMENT.md) for detailed guide

**Option B: DigitalOcean (Easiest)**
1. Go to https://www.digitalocean.com
2. Sign up and create a Droplet
3. Choose: Ubuntu 22.04 LTS, Regular ($24/month)
4. Get your server IP (e.g., `138.68.123.45`)

**Option C: Vultr (Best Value)**
1. Go to https://www.vultr.com
2. Sign up and deploy a server
3. Choose: Ubuntu 22.04 LTS, Regular Performance ($24/month)
4. Get your server IP

**Option D: Hetzner (Budget)**
1. Go to https://www.hetzner.com
2. Sign up and create a cloud server
3. Choose: Ubuntu 22.04, CPX21 (€8.61/month ~$9)
4. Get your server IP

### Step 2: Update DuckDNS

```bash
# Get your server's IP (on the server)
curl -4 ifconfig.me

# Update DuckDNS to point to SERVER IP (not laptop IP)
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=YOUR_SERVER_IP"
```

### Step 3: Deploy to Server

**On your server:**
```bash
# SSH into server
ssh root@YOUR_SERVER_IP

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Clone repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app

# Create .env files
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env
nano backend-api/.env  # Add MongoDB URI
nano backend-chat/.env  # Add MongoDB URI

# Start containers
docker-compose up -d --build
```

### Step 4: Configure Nginx

Follow `DOCKER_EXPOSE_PUBLIC_URL.md` Step 2 to configure Nginx.

### Step 5: Verify

```bash
# Wait 5-10 minutes for DNS propagation
nslookup backend-chat.duckdns.org

# Should show your SERVER IP, not laptop IP
```

---

## Complete Guide

For detailed instructions, see:
- **AWS_EC2_DEPLOYMENT.md** - Complete AWS EC2 deployment guide ⭐
- **SERVER_PROVIDERS_GUIDE.md** - Where to get a server
- **SERVER_DEPLOYMENT_WITH_DOMAINS.md** - Complete deployment guide
- **LAPTOP_VS_SERVER_IP.md** - Understanding the difference

---

## Cost

- **Server:** $0-30/month (AWS Free Tier, DigitalOcean, Vultr, or Hetzner)
- **Domain:** FREE (DuckDNS)
- **SSL:** FREE (Let's Encrypt)
- **Total:** $0-30/month

**Note:** AWS offers 12 months free tier (t3.micro), but 1GB RAM may be too small. Recommended: t3.medium ($30/month) or DigitalOcean/Vultr ($24/month).

---

## Summary

**Current:** DNS points to laptop IP (not suitable)

**Solution:** 
1. Get a cloud server
2. Deploy Docker containers to server
3. Update DuckDNS to point to server IP
4. Configure Nginx
5. Your app will be accessible 24/7

**See:** `SERVER_PROVIDERS_GUIDE.md` for server options and `SERVER_DEPLOYMENT_WITH_DOMAINS.md` for deployment.

