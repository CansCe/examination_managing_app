# Server Providers Guide - Where to Get Your Server

This guide explains where to get a server to deploy your Exam Management App.

## Quick Answer

**Recommended for beginners:** DigitalOcean, Vultr, or Linode (easy setup, good documentation)

**Budget-friendly:** Vultr, Linode, or Hetzner (good performance for the price)

**Free tier available:** AWS (Free Tier), Google Cloud (Free Credits), Oracle Cloud (Always Free)

---

## Server Requirements

### Minimum Specifications
- **CPU:** 2 cores
- **RAM:** 4GB
- **Storage:** 20GB SSD
- **Bandwidth:** 1TB/month
- **OS:** Ubuntu 20.04+ or Debian 11+

### Recommended Specifications
- **CPU:** 4 cores
- **RAM:** 8GB
- **Storage:** 50GB SSD
- **Bandwidth:** 2TB/month
- **OS:** Ubuntu 22.04 LTS

### Estimated Cost
- **Budget:** $5-10/month
- **Recommended:** $12-20/month
- **High Performance:** $40+/month

---

## Recommended Providers

### 1. DigitalOcean (Recommended for Beginners) ⭐

**Pros:**
- Easy to use interface
- Excellent documentation
- Predictable pricing
- Good for beginners

**Pricing:**
- **Basic Droplet (2GB RAM, 1 CPU):** $12/month
- **Standard Droplet (4GB RAM, 2 CPU):** $24/month
- **Professional (8GB RAM, 4 CPU):** $48/month

**Get Started:**
1. Sign up at https://www.digitalocean.com
2. Create a Droplet (Ubuntu 22.04 LTS)
3. Choose your plan (Standard $24/month recommended)
4. Add your SSH key
5. Deploy!

**Link:** https://www.digitalocean.com

---

### 2. Vultr (Best Value) ⭐

**Pros:**
- Very affordable
- Good performance
- Multiple locations
- Pay-as-you-go pricing

**Pricing:**
- **Regular Performance (2GB RAM, 1 CPU):** $12/month
- **Regular Performance (4GB RAM, 2 CPU):** $24/month
- **Regular Performance (8GB RAM, 4 CPU):** $48/month

**Get Started:**
1. Sign up at https://www.vultr.com
2. Deploy a Server (Ubuntu 22.04)
3. Choose your plan
4. Select location (closest to your users)
5. Deploy!

**Link:** https://www.vultr.com

---

### 3. Linode (Now Akamai) ⭐

**Pros:**
- Good performance
- Transparent pricing
- Good documentation
- Reliable infrastructure

**Pricing:**
- **Shared CPU (2GB RAM, 1 CPU):** $12/month
- **Shared CPU (4GB RAM, 2 CPU):** $24/month
- **Shared CPU (8GB RAM, 4 CPU):** $48/month

**Get Started:**
1. Sign up at https://www.linode.com
2. Create a Linode (Ubuntu 22.04 LTS)
3. Choose your plan
4. Deploy!

**Link:** https://www.linode.com

---

### 4. Hetzner (Best Budget Option)

**Pros:**
- Very affordable (European provider)
- Excellent performance
- Good for budget-conscious users

**Pricing:**
- **CPX11 (2GB RAM, 2 CPU):** €4.51/month (~$5)
- **CPX21 (4GB RAM, 3 CPU):** €8.61/month (~$9)
- **CPX31 (8GB RAM, 4 CPU):** €17.11/month (~$18)

**Get Started:**
1. Sign up at https://www.hetzner.com
2. Create a Cloud Server (Ubuntu 22.04)
3. Choose your plan
4. Deploy!

**Link:** https://www.hetzner.com

**Note:** Primarily European data centers, but excellent value.

---

### 5. AWS (Amazon Web Services) ⭐

**Pros:**
- Industry standard
- Very scalable
- Free tier available (12 months)
- Extensive services
- Reliable infrastructure

**Pricing:**
- **t3.medium (4GB RAM, 2 CPU):** ~$30/month
- **Free Tier:** 750 hours/month for 12 months (t2.micro/t3.micro)
- **Pay-as-you-go:** Can be complex

**Get Started:**
1. Sign up at https://aws.amazon.com
2. Launch EC2 instance (Ubuntu 22.04)
3. Choose instance type (t3.medium recommended)
4. Configure security groups
5. Deploy!

**Link:** https://aws.amazon.com

**Free Tier:** 12 months free (t2.micro/t3.micro - 1GB RAM, may be too small)

**Detailed Guide:** See [AWS_EC2_DEPLOYMENT.md](AWS_EC2_DEPLOYMENT.md) for complete step-by-step instructions.

---

### 6. Google Cloud Platform

**Pros:**
- $300 free credits (90 days)
- Good performance
- Scalable
- Good documentation

**Pricing:**
- **e2-standard-2 (4GB RAM, 2 CPU):** ~$30/month
- **Free Credits:** $300 for 90 days
- **Always Free:** f1-micro (limited)

**Get Started:**
1. Sign up at https://cloud.google.com
2. Create VM instance (Ubuntu 22.04)
3. Choose machine type (e2-standard-2)
4. Deploy!

**Link:** https://cloud.google.com

**Free Credits:** $300 free credits for 90 days

---

### 7. Oracle Cloud (Always Free Tier)

**Pros:**
- Always Free tier available
- Good performance on free tier
- 2 VMs with 1GB RAM each (free forever)

**Pricing:**
- **Always Free:** 2 VMs (1GB RAM each) - FREE
- **Paid:** Competitive pricing

**Get Started:**
1. Sign up at https://www.oracle.com/cloud
2. Create VM instance (Ubuntu 22.04)
3. Use Always Free tier (limited resources)
4. Deploy!

**Link:** https://www.oracle.com/cloud

**Free Tier:** 2 VMs with 1GB RAM each (free forever, but may be too limited)

---

### 8. Azure (Microsoft)

**Pros:**
- $200 free credits (30 days)
- Good integration with Microsoft services
- Scalable

**Pricing:**
- **B2s (4GB RAM, 2 CPU):** ~$30/month
- **Free Credits:** $200 for 30 days

**Get Started:**
1. Sign up at https://azure.microsoft.com
2. Create Virtual Machine (Ubuntu 22.04)
3. Choose size (B2s)
4. Deploy!

**Link:** https://azure.microsoft.com

---

## Comparison Table

| Provider | Price/Month | RAM | CPU | Best For |
|----------|------------|-----|-----|----------|
| **DigitalOcean** | $24 | 4GB | 2 | Beginners |
| **Vultr** | $24 | 4GB | 2 | Best Value |
| **Linode** | $24 | 4GB | 2 | Reliability |
| **Hetzner** | €8.61 (~$9) | 4GB | 3 | Budget |
| **AWS** | $30 | 4GB | 2 | Enterprise |
| **Google Cloud** | $30 | 4GB | 2 | Scalability |
| **Oracle Cloud** | FREE | 1GB | 1 | Testing |
| **Azure** | $30 | 4GB | 2 | Microsoft Integration |

---

## Recommended for Your Project

### Option 1: Budget-Friendly (Recommended) ⭐

**Vultr or Hetzner**
- Cost: $12-24/month
- Performance: Good
- Best for: Small to medium deployments

### Option 2: Beginner-Friendly

**DigitalOcean**
- Cost: $24/month
- Performance: Good
- Best for: Easy setup and good documentation

### Option 3: Free Testing

**Oracle Cloud Always Free**
- Cost: FREE
- Performance: Limited (1GB RAM)
- Best for: Testing and learning (may be too limited for production)

### Option 4: Enterprise

**AWS or Google Cloud**
- Cost: $30+/month
- Performance: Excellent
- Best for: Large scale deployments

---

## Step-by-Step: Getting a Server (DigitalOcean Example)

### Step 1: Sign Up

1. Go to https://www.digitalocean.com
2. Click "Sign Up"
3. Create an account (email verification required)

### Step 2: Create a Droplet

1. Click "Create" → "Droplets"
2. Choose:
   - **Image:** Ubuntu 22.04 LTS
   - **Plan:** Regular (Standard $24/month - 4GB RAM, 2 CPU)
   - **Region:** Choose closest to your users
   - **Authentication:** SSH keys (recommended) or password
3. Click "Create Droplet"

### Step 3: Connect to Your Server

```bash
# SSH into your server (replace YOUR_IP with your server IP)
ssh root@YOUR_SERVER_IP

# Or if you used a non-root user
ssh username@YOUR_SERVER_IP
```

### Step 4: Update Your Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker (see SERVER_DEPLOYMENT_WITH_DOMAINS.md)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Step 5: Deploy Your App

Follow the instructions in `SERVER_DEPLOYMENT_WITH_DOMAINS.md`

---

## Step-by-Step: Getting a Server (Vultr Example)

### Step 1: Sign Up

1. Go to https://www.vultr.com
2. Click "Sign Up"
3. Create an account

### Step 2: Deploy a Server

1. Click "Products" → "Compute" → "Deploy Server"
2. Choose:
   - **Server Type:** Cloud Compute
   - **CPU & Storage:** Regular Performance (4GB RAM, 2 CPU) - $24/month
   - **Server Location:** Choose closest to your users
   - **Operating System:** Ubuntu 22.04 LTS
   - **Server Hostname:** exam-management-server
3. Click "Deploy Now"

### Step 3: Connect to Your Server

```bash
# SSH into your server
ssh root@YOUR_SERVER_IP
```

### Step 4: Deploy Your App

Follow the instructions in `SERVER_DEPLOYMENT_WITH_DOMAINS.md`

---

## Free Options (For Testing)

### Oracle Cloud Always Free

1. Sign up at https://www.oracle.com/cloud
2. Create a VM instance (Always Free tier)
3. **Limitations:**
   - 1GB RAM (may be too small)
   - Limited CPU
   - 2 VMs maximum

### AWS Free Tier

1. Sign up at https://aws.amazon.com
2. Launch EC2 instance (t2.micro - Free Tier)
3. **Limitations:**
   - 1GB RAM (may be too small)
   - Only 12 months free
   - Limited resources

### Google Cloud Free Credits

1. Sign up at https://cloud.google.com
2. Get $300 free credits (90 days)
3. Create VM instance
4. **Limitations:**
   - Credits expire after 90 days
   - Pay-as-you-go after credits

---

## What You Need After Getting a Server

1. **Server IP Address** - You'll get this after creating the server
2. **SSH Access** - To connect to your server
3. **Root/Sudo Access** - To install software
4. **Domain DNS Configuration** - Point your DuckDNS domains to your server IP

### Update DuckDNS with Your Server IP

```bash
# Get your server's public IP
curl -4 ifconfig.me

# Update DuckDNS (replace YOUR_TOKEN with your DuckDNS token)
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_DUCKDNS_TOKEN&ip=YOUR_SERVER_IP"
```

---

## Security Considerations

1. **Firewall:** Configure UFW or iptables
2. **SSH Keys:** Use SSH keys instead of passwords
3. **Regular Updates:** Keep your server updated
4. **Backups:** Set up regular backups
5. **Monitoring:** Monitor your server resources

---

## Cost Estimation

### Monthly Costs

- **Server:** $12-24/month (recommended)
- **Domain:** FREE (DuckDNS) or $10-15/year (purchased domain)
- **SSL Certificate:** FREE (Let's Encrypt)
- **MongoDB:** FREE (MongoDB Atlas free tier) or $9/month (M0 cluster)

### Total Monthly Cost

- **Minimum:** $12/month (Vultr/Hetzner + Free services)
- **Recommended:** $24/month (DigitalOcean/Vultr + Free services)
- **With MongoDB Atlas:** $33/month (Server + MongoDB M0)

---

## Recommendations

### For Learning/Testing

**Oracle Cloud Always Free** or **AWS Free Tier**
- Cost: FREE
- Good for: Learning and testing
- Limitations: Limited resources

### For Production (Small Scale)

**Vultr or Hetzner**
- Cost: $12-24/month
- Good for: Small to medium deployments
- Performance: Good

### For Production (Recommended)

**DigitalOcean**
- Cost: $24/month
- Good for: Reliable production deployment
- Performance: Good
- Support: Excellent documentation

### For Enterprise

**AWS or Google Cloud**
- Cost: $30+/month
- Good for: Large scale deployments
- Performance: Excellent
- Scalability: Very scalable

---

## Next Steps

1. **Choose a provider** from the list above
2. **Sign up** and create a server
3. **Get your server IP** address
4. **Update DuckDNS** with your server IP
5. **Follow** `SERVER_DEPLOYMENT_WITH_DOMAINS.md` to deploy your app

---

## Troubleshooting

### Server Too Slow?

- Upgrade to a larger plan (more CPU/RAM)
- Check server resources: `htop` or `docker stats`
- Optimize your application

### Server Costs Too Much?

- Downgrade to a smaller plan
- Use Hetzner (cheaper option)
- Use Oracle Cloud Always Free (limited resources)

### Can't Connect to Server?

- Check firewall settings
- Verify SSH key is correct
- Check server status in provider dashboard

---

## Additional Resources

- [SERVER_DEPLOYMENT_WITH_DOMAINS.md](SERVER_DEPLOYMENT_WITH_DOMAINS.md) - Complete deployment guide
- [DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md) - Domain setup guide
- [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) - Docker deployment guide

---

## Summary

**Best Options:**
1. **DigitalOcean** - Easy to use, good documentation ($24/month)
2. **Vultr** - Best value, good performance ($24/month)
3. **Hetzner** - Budget-friendly, excellent performance (€8.61/month ~$9)

**Free Options:**
1. **Oracle Cloud** - Always Free tier (limited resources)
2. **AWS** - 12 months free tier (limited resources)
3. **Google Cloud** - $300 free credits (90 days)

**Recommended:** Start with **DigitalOcean** or **Vultr** for $24/month. They offer good performance, easy setup, and reliable service.

