# Quick Domain Setup Guide

## 🚀 Quick Options for API Domain

### Option 1: Free with DuckDNS (Easiest, Recommended for Testing)

**Steps:**
1. Go to https://www.duckdns.org
2. Sign in with GitHub/Google (free)
3. Create a subdomain (e.g., `examapp`)
4. You'll get: `examapp.duckdns.org`
5. Install update script on your server (see below)

**On Your Server:**
```bash
# Create update script
mkdir -p ~/duckdns
echo 'echo url="https://www.duckdns.org/update?domains=examapp&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -' > ~/duckdns/duck.sh
chmod +x ~/duckdns/duck.sh

# Add to cron (updates every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -
```

**Build Your App:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://examapp.duckdns.org:3000 \
  --dart-define=CHAT_BASE_URL=http://examapp.duckdns.org:3001
```

**Pros:**
- ✅ Free
- ✅ Easy setup (5 minutes)
- ✅ Works with changing IPs
- ✅ No credit card required

**Cons:**
- ⚠️ Less professional (subdomain only)
- ⚠️ HTTP only (no HTTPS by default)

---

### Option 2: Purchase Domain (Best for Production)

**Steps:**
1. Go to https://www.namecheap.com (or Google Domains, Cloudflare)
2. Search for domain name (e.g., `exammanagement.com`)
3. Purchase ($10-15/year)
4. Configure DNS to point to your server IP
5. Setup SSL certificate (free with Let's Encrypt)

**Build Your App:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.exammanagement.com \
  --dart-define=CHAT_BASE_URL=https://chat.exammanagement.com
```

**Pros:**
- ✅ Professional
- ✅ Can use HTTPS (secure)
- ✅ Custom domain name
- ✅ Better for production

**Cons:**
- 💰 Costs $10-15/year
- ⚠️ Requires SSL setup

---

### Option 3: Use IP Address (Development Only)

**Steps:**
1. Find your server's IP address
2. Use it directly in the app

**Build Your App:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://192.168.1.100:3000 \
  --dart-define=CHAT_BASE_URL=http://192.168.1.100:3001
```

**Pros:**
- ✅ Free
- ✅ Immediate (no setup)
- ✅ Good for testing

**Cons:**
- ❌ Not secure (HTTP only)
- ❌ Hard to remember
- ❌ IP can change
- ❌ Not for production

---

## 📊 Comparison

| Method | Cost | Setup Time | Security | Professional | Best For |
|--------|------|------------|----------|--------------|----------|
| **DuckDNS** | Free | 5 min | Medium | ⭐⭐ | Testing/Small Projects |
| **Purchased Domain** | $10-15/yr | 30 min | High | ⭐⭐⭐ | Production |
| **IP Address** | Free | 0 min | Low | ⭐ | Development Only |

---

## 🎯 Recommendation

### For Testing/Small Projects:
**Use DuckDNS** - Free, easy, works great for testing

### For Production:
**Purchase a domain** - Professional, secure, worth the $10-15/year

### For Development:
**Use IP address** - Quick and easy for local testing

---

## 🔒 Security Notes

- **Always use HTTPS in production** (mobile apps require it)
- **DuckDNS** can work with HTTPS if you setup SSL
- **IP addresses** are NOT secure for production
- **Purchased domains** + Let's Encrypt SSL = Best security

---

## 📚 More Details

For complete setup instructions, see:
- **[DOMAIN_SETUP_GUIDE.md](DOMAIN_SETUP_GUIDE.md)** - Detailed guide with all options
- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Full deployment guide

---

## 🚀 Quick Start with DuckDNS (5 Minutes)

1. **Sign up:** https://www.duckdns.org
2. **Create subdomain:** Choose a name (e.g., `examapp`)
3. **Get your token:** Copy from dashboard
4. **Update IP automatically:**
   ```bash
   # On your server
   mkdir -p ~/duckdns
   echo 'echo url="https://www.duckdns.org/update?domains=examapp&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -' > ~/duckdns/duck.sh
   chmod +x ~/duckdns/duck.sh
   (crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -
   ```
5. **Build app:**
   ```bash
   flutter build apk --release \
     --dart-define=API_BASE_URL=http://examapp.duckdns.org:3000 \
     --dart-define=CHAT_BASE_URL=http://examapp.duckdns.org:3001
   ```

**Done!** Your app will connect to `examapp.duckdns.org`

---

## 💡 Tips

- **DuckDNS is perfect for testing** - Free, easy, works immediately
- **Upgrade to purchased domain** when you're ready for production
- **Use HTTPS** for production (required for mobile apps)
- **Setup SSL with Let's Encrypt** (free, automatic renewal)

