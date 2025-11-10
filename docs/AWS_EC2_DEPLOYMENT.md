# AWS EC2 Deployment Guide

Complete step-by-step guide for deploying your Exam Management App to AWS EC2.

## Prerequisites

- AWS account (sign up at https://aws.amazon.com)
- Credit card (for account verification, but you can use Free Tier)
- Basic understanding of SSH and command line
- DuckDNS domains configured

---

## Step 1: Create AWS Account

1. **Sign up:** Go to https://aws.amazon.com
2. **Create account:** Fill in your details
3. **Verify email:** Check your email and verify
4. **Add payment method:** Required for account verification (won't be charged if using Free Tier)
5. **Complete registration:** Wait for account activation

**Free Tier:** AWS offers 12 months free tier (750 hours/month of t2.micro or t3.micro)

---

## Step 2: Launch EC2 Instance

### 2.1 Navigate to EC2

1. **Login to AWS Console:** https://console.aws.amazon.com
2. **Search for EC2:** Type "EC2" in the search bar
3. **Click "EC2":** Open EC2 Dashboard
4. **Select Region:** Choose closest region (e.g., `us-east-1`, `eu-west-1`)

### 2.2 Launch Instance

1. **Click "Launch Instance":** Orange button in the EC2 Dashboard
2. **Name your instance:** Enter a name (e.g., `exam-management-app`)

### 2.3 Choose AMI (Amazon Machine Image)

1. **Select Ubuntu:** Choose "Ubuntu Server 22.04 LTS"
2. **Architecture:** Select "64-bit (x86)"

**Free Tier Eligible:** Ubuntu 22.04 is free tier eligible

### 2.4 Choose Instance Type

**For Free Tier (Limited):**
- **t2.micro:** 1 vCPU, 1GB RAM (Free Tier, but may be too small)
- **t3.micro:** 1 vCPU, 1GB RAM (Free Tier eligible)

**Recommended (Paid):**
- **t3.small:** 2 vCPU, 2GB RAM (~$15/month)
- **t3.medium:** 2 vCPU, 4GB RAM (~$30/month) ⭐ Recommended

**Note:** For production, use at least **t3.medium** (4GB RAM). Free tier (1GB RAM) may not be sufficient.

### 2.5 Create Key Pair

1. **Key pair name:** Enter a name (e.g., `exam-app-key`)
2. **Key pair type:** Select "RSA"
3. **Private key file format:** Select ".pem" (for Linux/Mac) or ".ppk" (for Windows PuTTY)
4. **Click "Create key pair":** This downloads the key file

**⚠️ Important:** Save this key file securely! You'll need it to SSH into your server.

**For Windows:** If you downloaded `.pem`, you may need to convert it to `.ppk` using PuTTYgen, or use WSL/OpenSSH.

### 2.6 Configure Network Settings

1. **VPC:** Leave default
2. **Subnet:** Leave default
3. **Auto-assign Public IP:** Enable
4. **Security Group:** Create new security group
5. **Security group name:** `exam-app-sg`
6. **Description:** `Security group for Exam Management App`

**Add Rules:**
- **SSH (22):** Allow from "My IP" (or 0.0.0.0/0 for testing, but not recommended for production)
- **HTTP (80):** Allow from "Anywhere-IPv4" (0.0.0.0/0)
- **HTTPS (443):** Allow from "Anywhere-IPv4" (0.0.0.0/0)
- **Custom TCP (3000):** Allow from "Anywhere-IPv4" (0.0.0.0/0) - For API
- **Custom TCP (3001):** Allow from "Anywhere-IPv4" (0.0.0.0/0) - For Chat

**Note:** For production, restrict SSH (22) to your IP only.

### 2.7 Configure Storage

1. **Volume size:** 20GB (minimum) or 30GB (recommended)
2. **Volume type:** gp3 (General Purpose SSD)
3. **Delete on termination:** Leave unchecked (to keep data)

**Free Tier:** 30GB of EBS storage is free for 12 months

### 2.8 Launch Instance

1. **Review:** Check all settings
2. **Click "Launch Instance":** Instance will be created
3. **View Instances:** Click "View Instances"

---

## Step 3: Get Your Server IP

1. **Wait for instance:** Status should be "Running" (green)
2. **Copy Public IP:** Click on your instance and copy the "Public IPv4 address"
3. **Example:** `54.123.45.67`

**Note:** This IP is your server IP (not your laptop IP). You'll use this to update DuckDNS.

---

## Step 4: Connect to Your Server

### Option A: Windows (Using WSL or PowerShell)

1. **Open PowerShell or WSL:**
```bash
# If using WSL
wsl

# Navigate to where you saved your key
cd ~/Downloads
```

2. **Set correct permissions (Linux/WSL):**
```bash
chmod 400 exam-app-key.pem
```

3. **SSH into server:**
```bash
ssh -i exam-app-key.pem ubuntu@YOUR_SERVER_IP
```

**Example:**
```bash
ssh -i exam-app-key.pem ubuntu@54.123.45.67
```

### Option B: Windows (Using PuTTY)

1. **Download PuTTY:** https://www.putty.org
2. **Convert .pem to .ppk:**
   - Open PuTTYgen
   - Click "Load" and select your `.pem` file
   - Click "Save private key" and save as `.ppk`
3. **Connect:**
   - Open PuTTY
   - Host: `ubuntu@YOUR_SERVER_IP`
   - Port: 22
   - Connection > SSH > Auth > Credentials: Browse and select your `.ppk` file
   - Click "Open"

### Option C: Mac/Linux

1. **Set correct permissions:**
```bash
chmod 400 exam-app-key.pem
```

2. **SSH into server:**
```bash
ssh -i exam-app-key.pem ubuntu@YOUR_SERVER_IP
```

---

## Step 5: Install Docker on Server

Once connected to your server:

### 5.1 Update System

```bash
sudo apt update
sudo apt upgrade -y
```

### 5.2 Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo apt install docker-compose -y

# Verify installation
docker --version
docker-compose --version
```

### 5.3 Logout and Login Again

```bash
exit
# SSH back in
ssh -i exam-app-key.pem ubuntu@YOUR_SERVER_IP
```

---

## Step 6: Clone Your Repository

```bash
# Install Git
sudo apt install git -y

# Clone repository
git clone https://github.com/yourusername/exam_management_app.git
cd exam_management_app
```

**Or upload files manually:**
- Use `scp` to upload files
- Or use AWS Systems Manager Session Manager
- Or use FileZilla with SFTP

---

## Step 7: Configure Environment Variables

### 7.1 Create .env Files

```bash
# Create .env files
cp backend-api/ENV_EXAMPLE.txt backend-api/.env
cp backend-chat/ENV_EXAMPLE.txt backend-chat/.env

# Edit .env files
nano backend-api/.env
nano backend-chat/.env
```

### 7.2 Configure MongoDB URI

Edit both `.env` files and add your MongoDB Atlas URI:

```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/
MONGODB_DB=exam_management
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org
DEFAULT_ADMIN_ID=your-admin-id
```

**Save and exit:** `Ctrl+X`, then `Y`, then `Enter`

---

## Step 8: Update DuckDNS

### 8.1 Get Your Server IP

```bash
# On your server
curl -4 ifconfig.me
```

### 8.2 Update DuckDNS

On your local machine (or server):

```bash
# Update DuckDNS to point to SERVER IP (not laptop IP)
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=YOUR_SERVER_IP"
```

**Replace:**
- `YOUR_TOKEN`: Your DuckDNS token
- `YOUR_SERVER_IP`: Your EC2 instance's public IP (e.g., `54.123.45.67`)

### 8.3 Verify DNS

```bash
# Wait 5-10 minutes, then check
nslookup backend-chat.duckdns.org
# Should show your SERVER IP, not laptop IP
```

---

## Step 9: Deploy Docker Containers

### 9.1 Start Containers

```bash
# Make sure you're in the project directory
cd ~/exam_management_app

# Start containers
docker-compose up -d --build
```

### 9.2 Check Status

```bash
# Check running containers
docker ps

# Check logs
docker-compose logs -f
```

### 9.3 Verify Services

```bash
# Test API
curl http://localhost:3000/health

# Test Chat
curl http://localhost:3001/health
```

---

## Step 10: Configure Nginx

### 10.1 Install Nginx

```bash
sudo apt install nginx -y
```

### 10.2 Create Nginx Config

```bash
# Create API config
sudo nano /etc/nginx/sites-available/exam-app-api.duckdns.org
```

**Add this content:**
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

### 10.3 Create Chat Config

```bash
# Create Chat config
sudo nano /etc/nginx/sites-available/backend-chat.duckdns.org
```

**Add this content:**
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

        # WebSocket support
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

**Save and exit:** `Ctrl+X`, then `Y`, then `Enter`

### 10.4 Enable Sites

```bash
# Enable sites
sudo ln -s /etc/nginx/sites-available/exam-app-api.duckdns.org /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/backend-chat.duckdns.org /etc/nginx/sites-enabled/

# Test Nginx config
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### 10.5 Verify Nginx

```bash
# Check Nginx status
sudo systemctl status nginx

# Test from browser
# http://exam-app-api.duckdns.org
# http://backend-chat.duckdns.org
```

---

## Step 11: Setup SSL (Optional but Recommended)

### 11.1 Install Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

### 11.2 Get SSL Certificates

```bash
# Get certificates for both domains
sudo certbot --nginx -d exam-app-api.duckdns.org -d backend-chat.duckdns.org
```

### 11.3 Verify SSL

```bash
# Test SSL
curl https://exam-app-api.duckdns.org
curl https://backend-chat.duckdns.org
```

---

## Step 12: Configure Firewall (Security Groups)

### 12.1 Update Security Group

1. **Go to EC2 Console:** https://console.aws.amazon.com/ec2
2. **Click "Security Groups":** Left sidebar
3. **Select your security group:** `exam-app-sg`
4. **Edit Inbound Rules:**
   - **SSH (22):** Restrict to "My IP" only (for security)
   - **HTTP (80):** Allow from "Anywhere-IPv4"
   - **HTTPS (443):** Allow from "Anywhere-IPv4"
   - **Remove ports 3000 and 3001:** Not needed (Nginx handles routing)

### 12.2 Save Rules

Click "Save rules" to apply changes.

---

## Step 13: Test Your Deployment

### 13.1 Test API

```bash
# From your local machine
curl https://exam-app-api.duckdns.org/health
```

### 13.2 Test Chat

```bash
# From your local machine
curl https://backend-chat.duckdns.org/health
```

### 13.3 Test from Browser

- **API:** https://exam-app-api.duckdns.org
- **Chat:** https://backend-chat.duckdns.org

---

## Cost Estimation

### Free Tier (12 Months)

- **EC2 t2.micro/t3.micro:** 750 hours/month - **FREE**
- **EBS Storage:** 30GB - **FREE**
- **Data Transfer:** 15GB out - **FREE**
- **Total:** **$0/month** (for 12 months)

**Note:** Free tier (1GB RAM) may not be sufficient for production.

### Paid Tier (Recommended)

- **EC2 t3.medium (4GB RAM, 2 CPU):** ~$30/month
- **EBS Storage (30GB):** ~$3/month
- **Data Transfer:** ~$5/month (first 10GB free)
- **Total:** ~$35-40/month

### Cost Optimization Tips

1. **Use Reserved Instances:** Save up to 75% (1-year commitment)
2. **Use Spot Instances:** Save up to 90% (for non-critical workloads)
3. **Monitor usage:** Set up billing alerts
4. **Use Free Tier:** For testing/development

---

## Troubleshooting

### Issue: Can't SSH into Server

**Solution:**
1. Check security group allows SSH (22) from your IP
2. Verify key file permissions: `chmod 400 exam-app-key.pem`
3. Check instance status is "Running"
4. Verify you're using the correct key file

### Issue: Services Not Accessible

**Solution:**
1. Check security group allows HTTP (80) and HTTPS (443)
2. Verify Docker containers are running: `docker ps`
3. Check Nginx is running: `sudo systemctl status nginx`
4. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`

### Issue: DNS Not Resolving

**Solution:**
1. Wait 5-10 minutes for DNS propagation
2. Verify DuckDNS is updated: Check DuckDNS dashboard
3. Clear DNS cache: `ipconfig /flushdns` (Windows) or `sudo systemd-resolve --flush-caches` (Linux)

### Issue: Out of Memory

**Solution:**
1. Upgrade instance type to t3.medium (4GB RAM)
2. Monitor memory usage: `free -h`
3. Optimize Docker containers

### Issue: High Costs

**Solution:**
1. Monitor AWS Cost Explorer
2. Set up billing alerts
3. Use Reserved Instances for long-term savings
4. Consider switching to DigitalOcean or Vultr ($24/month)

---

## Security Best Practices

### 1. Restrict SSH Access

- Only allow SSH (22) from your IP
- Use key pairs (not passwords)
- Disable root login

### 2. Use Security Groups

- Only open necessary ports
- Restrict access to specific IPs where possible
- Regularly review security group rules

### 3. Keep System Updated

```bash
sudo apt update
sudo apt upgrade -y
```

### 4. Use SSL/HTTPS

- Always use SSL certificates (Let's Encrypt)
- Redirect HTTP to HTTPS
- Use strong SSL/TLS configuration

### 5. Monitor Logs

```bash
# Check Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Check Docker logs
docker-compose logs -f
```

### 6. Regular Backups

- Backup your `.env` files
- Backup your database
- Use AWS Snapshots for EBS volumes

---

## Maintenance

### Update Docker Containers

```bash
# Pull latest changes
git pull

# Rebuild and restart containers
docker-compose down
docker-compose up -d --build
```

### Update System

```bash
# Update system packages
sudo apt update
sudo apt upgrade -y

# Restart services if needed
sudo systemctl restart nginx
docker-compose restart
```

### Monitor Resources

```bash
# Check CPU and memory
htop

# Check disk usage
df -h

# Check Docker containers
docker stats
```

---

## Next Steps

1. **Setup Monitoring:** Use AWS CloudWatch to monitor your instance
2. **Setup Alerts:** Configure billing alerts and instance health checks
3. **Setup Backups:** Configure EBS snapshots for backups
4. **Optimize Costs:** Use Reserved Instances or Spot Instances
5. **Scale Up:** Upgrade instance type if needed

---

## Summary

**What You've Done:**
1. ✅ Created AWS EC2 instance
2. ✅ Configured security groups
3. ✅ Installed Docker
4. ✅ Deployed your app
5. ✅ Configured Nginx
6. ✅ Updated DuckDNS
7. ✅ Setup SSL certificates

**Your App is Now:**
- Accessible at https://exam-app-api.duckdns.org
- Accessible at https://backend-chat.duckdns.org
- Running on a cloud server (not laptop)
- Secure with SSL/HTTPS
- Scalable and reliable

**Cost:** $0-40/month (depending on instance type)

**See Also:**
- `SERVER_DEPLOYMENT_WITH_DOMAINS.md` - General deployment guide
- `DOCKER_EXPOSE_PUBLIC_URL.md` - Nginx configuration details
- `SERVER_PROVIDERS_GUIDE.md` - Comparison of server providers

---

## Additional Resources

- **AWS EC2 Documentation:** https://docs.aws.amazon.com/ec2
- **AWS Free Tier:** https://aws.amazon.com/free
- **AWS Pricing Calculator:** https://calculator.aws.amazon.com
- **AWS Support:** https://aws.amazon.com/support

---

## Quick Reference

### Important Commands

```bash
# SSH into server
ssh -i exam-app-key.pem ubuntu@YOUR_SERVER_IP

# Check Docker containers
docker ps
docker-compose logs -f

# Restart services
docker-compose restart
sudo systemctl restart nginx

# Check Nginx status
sudo systemctl status nginx
sudo nginx -t

# Update DuckDNS
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=YOUR_SERVER_IP"
```

### Important Files

- **Security Group:** EC2 Console > Security Groups
- **Instance IP:** EC2 Console > Instances
- **Key Pair:** Downloaded `.pem` file
- **Nginx Config:** `/etc/nginx/sites-available/`
- **Docker Compose:** `docker-compose.yml`

---

**Congratulations!** Your app is now running on AWS EC2! 🎉

