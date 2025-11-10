# Domain Setup Guide for API and Chat Services

This guide explains how to get domain names for your API and chat services, and explores safer alternatives.

## Table of Contents
1. [Domain Registration](#domain-registration)
2. [Free Domain Options](#free-domain-options)
3. [Alternatives to Domains](#alternatives-to-domains)
4. [Security Best Practices](#security-best-practices)
5. [Step-by-Step Setup](#step-by-step-setup)

---

## Domain Registration

### What is a Domain?

A domain name (e.g., `yourdomain.com`) is a human-readable address that points to your server's IP address. Instead of remembering `192.168.1.100:3000`, users can use `api.yourdomain.com`.

### How to Get a Domain

#### Option 1: Purchase a Domain (Recommended for Production)

**Popular Domain Registrars:**
- **Namecheap** (https://www.namecheap.com) - $8-15/year
- **Google Domains** (https://domains.google) - $12/year
- **Cloudflare** (https://www.cloudflare.com/products/registrar) - At-cost pricing
- **GoDaddy** (https://www.godaddy.com) - $12-15/year
- **Name.com** (https://www.name.com) - $10-15/year

**Steps:**
1. Visit a registrar website
2. Search for available domain names
3. Choose a domain (e.g., `exammanagement.com`)
4. Complete purchase (usually $10-15/year)
5. Configure DNS settings

#### Option 2: Free Domain Services

**Free Domain Providers:**
- **Freenom** (https://www.freenom.com) - Free `.tk`, `.ml`, `.ga` domains
- **No-IP** (https://www.noip.com) - Free dynamic DNS
- **DuckDNS** (https://www.duckdns.org) - Free subdomains (e.g., `yoursite.duckdns.org`)

**Limitations:**
- Free domains may have restrictions
- Less professional appearance
- May require renewal more frequently
- Some services show ads

---

## Alternatives to Domains

### Option 1: Use IP Address (Development/Testing Only)

**Pros:**
- No cost
- Immediate setup
- Good for testing

**Cons:**
- Not secure (HTTP only, no SSL)
- Hard to remember
- IP addresses can change
- Not professional
- No SSL certificates (browsers show warnings)

**Usage:**
```bash
# Build with IP address
flutter build apk --release \
  --dart-define=API_BASE_URL=http://192.168.1.100:3000 \
  --dart-define=CHAT_BASE_URL=http://192.168.1.100:3001
```

**When to Use:**
- Local testing
- Development
- Internal networks
- **NOT for production**

---

### Option 2: Dynamic DNS Services (Free Alternative)

**Services:**
- **DuckDNS** (https://www.duckdns.org) - Free, simple setup
- **No-IP** (https://www.noip.com) - Free with limitations
- **Dynu** (https://www.dynu.com) - Free dynamic DNS

**How It Works:**
1. Sign up for free account
2. Get a subdomain (e.g., `yourapp.duckdns.org`)
3. Install update client on server
4. Use the subdomain in your app

**Example:**
```bash
# Your server updates its IP automatically
# You get: yourapp.duckdns.org
flutter build apk --release \
  --dart-define=API_BASE_URL=http://yourapp.duckdns.org:3000 \
  --dart-define=CHAT_BASE_URL=http://yourapp.duckdns.org:3001
```

**Pros:**
- Free
- Works with changing IPs
- More professional than raw IP
- Easy setup

**Cons:**
- Less professional than custom domain
- May have usage limits
- Subdomain only (not root domain)

---

### Option 3: Cloud Provider Domains

**Services:**
- **AWS Route 53** - Domain registration + DNS
- **Google Cloud DNS** - DNS hosting
- **Cloudflare** - Free DNS + domain registration
- **Azure DNS** - DNS hosting

**Benefits:**
- Integrated with cloud services
- Reliable infrastructure
- Good security features
- Free DNS hosting (Cloudflare)

**Example with Cloudflare:**
1. Register domain through Cloudflare (at-cost pricing)
2. Get free DNS hosting
3. Free SSL certificates
4. DDoS protection included

---

### Option 4: Reverse Proxy Tunnels (For Testing)

**Services:**
- **ngrok** (https://ngrok.com) - Free tunnel service
- **localhost.run** (https://localhost.run) - Free SSH tunnel
- **Cloudflare Tunnel** (https://cloudflare.com/products/tunnel) - Free

**How It Works:**
- Creates a public URL that tunnels to your local server
- Useful for testing without deploying

**Example with ngrok:**
```bash
# Install ngrok
# Start tunnel
ngrok http 3000

# Get public URL: https://abc123.ngrok.io
# Use in app temporarily
```

**Pros:**
- Free for testing
- No server setup needed
- HTTPS included
- Good for development

**Cons:**
- URLs change on free plan
- Not for production
- Rate limits on free plan

---

## Security Best Practices

### 1. Always Use HTTPS in Production

**Why:**
- Encrypts data in transit
- Prevents man-in-the-middle attacks
- Required for mobile apps (iOS/Android enforce HTTPS)

**How to Get SSL Certificate:**
- **Let's Encrypt** (Free, recommended)
- **Cloudflare** (Free SSL)
- **Commercial certificates** (Paid, $50-200/year)

### 2. Use Subdomains

**Structure:**
- `api.yourdomain.com` - Main API
- `chat.yourdomain.com` - Chat service
- `www.yourdomain.com` - Website (if needed)

**Benefits:**
- Better organization
- Easier to manage
- Can use different SSL certificates
- Can scale services independently

### 3. Domain Security

**DNS Security:**
- Use DNSSEC (Domain Name System Security Extensions)
- Use reputable DNS provider
- Enable DNS over HTTPS (DoH)

**SSL/TLS:**
- Use TLS 1.2 or higher
- Enable HSTS (HTTP Strict Transport Security)
- Use strong cipher suites

---

## Step-by-Step Setup

### Scenario 1: Using a Purchased Domain (Recommended)

#### Step 1: Purchase Domain
1. Go to Namecheap/Google Domains
2. Search for domain name
3. Purchase domain ($10-15/year)

#### Step 2: Configure DNS
1. Get your server's IP address
2. Login to domain registrar
3. Add DNS records:
   ```
   Type: A
   Name: api
   Value: YOUR_SERVER_IP
   TTL: 3600
   
   Type: A
   Name: chat
   Value: YOUR_SERVER_IP
   TTL: 3600
   ```

#### Step 3: Setup SSL Certificate
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

#### Step 4: Build App
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

---

### Scenario 2: Using DuckDNS (Free)

#### Step 1: Sign Up
1. Go to https://www.duckdns.org
2. Sign up with GitHub/Google
3. Create a subdomain (e.g., `examapp`)

#### Step 2: Install Update Client
```bash
# On your server
sudo apt install curl

# Create update script
echo 'echo url="https://www.duckdns.org/update?domains=examapp&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -' > ~/duckdns/duck.sh

# Make executable
chmod +x ~/duckdns/duck.sh

# Add to cron (update every 5 minutes)
*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```

#### Step 3: Configure Nginx
```nginx
server {
    listen 80;
    server_name examapp.duckdns.org;

    location / {
        proxy_pass http://localhost:3000;
    }
}
```

#### Step 4: Build App
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://examapp.duckdns.org:3000 \
  --dart-define=CHAT_BASE_URL=http://examapp.duckdns.org:3001
```

---

### Scenario 3: Using IP Address (Development Only)

#### Step 1: Find Server IP
```bash
# On your server
ip addr show
# or
curl ifconfig.me
```

#### Step 2: Configure Firewall
```bash
# Allow ports
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp
```

#### Step 3: Build App
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://YOUR_IP:3000 \
  --dart-define=CHAT_BASE_URL=http://YOUR_IP:3001
```

**⚠️ Warning:** This is NOT secure for production. Use only for testing.

---

## Comparison Table

| Method | Cost | Security | Setup Difficulty | Professional | Best For |
|--------|------|----------|------------------|--------------|----------|
| **Purchased Domain** | $10-15/year | ✅ High (HTTPS) | Medium | ✅✅✅ | Production |
| **DuckDNS** | Free | ⚠️ Medium (HTTP) | Easy | ✅✅ | Testing/Small Projects |
| **IP Address** | Free | ❌ Low (HTTP) | Very Easy | ❌ | Development Only |
| **Cloudflare** | At-cost | ✅ High (Free SSL) | Medium | ✅✅✅ | Production |
| **ngrok** | Free/Paid | ✅ High (HTTPS) | Very Easy | ⚠️ | Testing Only |

---

## Recommendations

### For Production:
1. **Purchase a domain** ($10-15/year)
2. **Use Cloudflare** for free DNS + SSL
3. **Setup subdomains** (api.yourdomain.com, chat.yourdomain.com)
4. **Use Let's Encrypt** for SSL certificates
5. **Enable HTTPS** everywhere

### For Development/Testing:
1. **Use DuckDNS** (free, easy setup)
2. **Or use IP address** (for local testing)
3. **Or use ngrok** (for temporary public access)

### For Small Projects:
1. **Use DuckDNS** (free subdomain)
2. **Setup basic SSL** (Let's Encrypt)
3. **Upgrade to domain** when ready

---

## Cost Breakdown

### Minimum Setup (Free):
- Domain: DuckDNS (free)
- DNS: DuckDNS (free)
- SSL: Let's Encrypt (free)
- **Total: $0/year**

### Recommended Setup (Low Cost):
- Domain: Namecheap ($10-15/year)
- DNS: Cloudflare (free)
- SSL: Let's Encrypt (free)
- **Total: $10-15/year**

### Professional Setup:
- Domain: Namecheap ($10-15/year)
- DNS: Cloudflare (free)
- SSL: Let's Encrypt (free)
- CDN: Cloudflare (free tier)
- **Total: $10-15/year**

---

## Quick Start: Free Setup with DuckDNS

### 1. Sign Up for DuckDNS
- Go to https://www.duckdns.org
- Sign in with GitHub/Google
- Create subdomain: `yourapp`

### 2. Get Your Token
- Copy your token from DuckDNS dashboard

### 3. Update IP Automatically
```bash
# Install on server
sudo apt install curl

# Create update script
mkdir -p ~/duckdns
echo 'echo url="https://www.duckdns.org/update?domains=yourapp&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -' > ~/duckdns/duck.sh
chmod +x ~/duckdns/duck.sh

# Test it
~/duckdns/duck.sh

# Add to cron (update every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -
```

### 4. Configure Your App
```bash
# Your domain will be: yourapp.duckdns.org
flutter build apk --release \
  --dart-define=API_BASE_URL=http://yourapp.duckdns.org:3000 \
  --dart-define=CHAT_BASE_URL=http://yourapp.duckdns.org:3001
```

---

## Security Considerations

### 1. Always Use HTTPS in Production
- Mobile apps require HTTPS
- Protects user data
- Prevents man-in-the-middle attacks

### 2. Use Strong SSL Certificates
- Let's Encrypt (free, trusted)
- Auto-renewal enabled
- TLS 1.2 or higher

### 3. Configure CORS Properly
- Only allow your app's origins
- Don't use `*` in production
- Update `ALLOWED_ORIGINS` in backend `.env`

### 4. Firewall Configuration
- Only expose necessary ports
- Use reverse proxy (Nginx)
- Enable rate limiting

---

## Troubleshooting

### Domain Not Resolving
1. Check DNS propagation: https://www.whatsmydns.net
2. Wait 24-48 hours for DNS to propagate
3. Check DNS records are correct
4. Clear DNS cache: `sudo systemd-resolve --flush-caches`

### SSL Certificate Issues
1. Check domain is pointing to correct IP
2. Verify ports 80 and 443 are open
3. Check Certbot logs: `sudo certbot certificates`
4. Renew certificate: `sudo certbot renew`

### Connection Refused
1. Check Docker services are running: `docker ps`
2. Verify firewall allows connections
3. Check server logs: `docker-compose logs`
4. Test locally: `curl http://localhost:3000/health`

---

## Next Steps

1. **Choose a method** based on your needs
2. **Setup domain/DNS** according to chosen method
3. **Configure SSL** (if using HTTPS)
4. **Update app configuration** with new URLs
5. **Build and test** the app
6. **Monitor and maintain** the setup

---

## Additional Resources

- **Let's Encrypt**: https://letsencrypt.org
- **DuckDNS**: https://www.duckdns.org
- **Cloudflare**: https://www.cloudflare.com
- **Namecheap**: https://www.namecheap.com
- **Certbot Guide**: https://certbot.eff.org

---

## Summary

**For Production:**
- ✅ Purchase domain ($10-15/year)
- ✅ Use Cloudflare (free DNS + SSL)
- ✅ Setup HTTPS with Let's Encrypt
- ✅ Use subdomains (api.yourdomain.com)

**For Testing:**
- ✅ Use DuckDNS (free)
- ✅ Or use IP address (development only)
- ✅ Or use ngrok (temporary testing)

**Security:**
- ✅ Always use HTTPS in production
- ✅ Use strong SSL certificates
- ✅ Configure CORS properly
- ✅ Use firewall rules

The safest and most professional method is to purchase a domain and use HTTPS with SSL certificates. For budget-conscious projects, DuckDNS provides a free alternative that's still functional for smaller deployments.

