# DNS Verification Guide

## Your DNS is Working! ✅

Based on your `nslookup` output:

```
Name:    backend-chat.duckdns.org
Address:  117.5.56.77
```

**This means:**
- ✅ DNS is resolving correctly
- ✅ Domain `backend-chat.duckdns.org` points to IP `117.5.56.77`
- ✅ DuckDNS is configured properly

## Next Steps

### 1. Verify Both Domains

Check both of your domains:

```bash
# Check API domain
nslookup exam-app-api.duckdns.org

# Check Chat domain
nslookup backend-chat.duckdns.org
```

**Expected:** Both should resolve to the same IP address (117.5.56.77)

### 2. Verify Server is Accessible

Test if your server is accessible at that IP:

```bash
# Test server accessibility
curl http://117.5.56.77

# Test if Nginx is running (if configured)
curl -I http://117.5.56.77

# Test Docker containers (if ports are exposed)
curl http://117.5.56.77:3000/health
curl http://117.5.56.77:3001/health
```

### 3. Verify Server IP Matches

Make sure your server's current IP matches the DNS record:

```bash
# On your server, check current IP
curl -4 ifconfig.me

# Should match: 117.5.56.77
```

**If IP doesn't match:**
- Update DuckDNS with the correct IP
- Wait 5-10 minutes for DNS propagation
- Verify again with `nslookup`

### 4. Configure Nginx (If Not Done)

If Nginx is not yet configured, follow Step 2 in `DOCKER_EXPOSE_PUBLIC_URL.md`:

1. Install Nginx
2. Create configuration files
3. Enable sites
4. Test configuration
5. Reload Nginx

### 5. Configure Firewall

Make sure ports 80 and 443 are open:

```bash
# On Linux server
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status

# On Windows server
# Use Windows Firewall settings or PowerShell commands
```

### 6. Test Domain Access

Once Nginx is configured, test domain access:

```bash
# Test API domain
curl http://exam-app-api.duckdns.org/health

# Test Chat domain
curl http://backend-chat.duckdns.org/health
```

## Troubleshooting

### DNS Resolves But Server Not Accessible

**Symptoms:**
- `nslookup` works (DNS resolves)
- `curl http://117.5.56.77` fails (server not accessible)

**Possible Causes:**
1. Firewall blocking ports 80/443
2. Nginx not running
3. Docker containers not running
4. Wrong server IP

**Solutions:**
```bash
# Check firewall
sudo ufw status

# Check Nginx
sudo systemctl status nginx

# Check Docker containers
docker ps

# Verify server IP
curl -4 ifconfig.me
```

### DNS Resolves But Wrong IP

**Symptoms:**
- `nslookup` shows different IP than server

**Solution:**
```bash
# Update DuckDNS with correct IP
curl "https://www.duckdns.org/update?domains=exam-app-api,backend-chat&token=YOUR_TOKEN&ip=$(curl -s ifconfig.me)"

# Wait 5-10 minutes for propagation
# Verify again
nslookup backend-chat.duckdns.org
```

### DNS Not Resolving

**Symptoms:**
- `nslookup` fails or shows no answer

**Possible Causes:**
1. DuckDNS not configured
2. Domain not activated
3. DNS propagation delay

**Solutions:**
1. Check DuckDNS at https://www.duckdns.org
2. Verify domain is active
3. Update DuckDNS if needed
4. Wait 5-10 minutes for propagation

## Quick Verification Checklist

- [ ] DNS resolves correctly (`nslookup` works)
- [ ] Server IP matches DNS record
- [ ] Server is accessible at IP address
- [ ] Ports 80/443 are open in firewall
- [ ] Nginx is installed and running
- [ ] Nginx configuration is correct
- [ ] Docker containers are running
- [ ] Domains are accessible via HTTP

## Summary

Your DNS is working correctly! The domain `backend-chat.duckdns.org` resolves to `117.5.56.77`.

**Next steps:**
1. Verify both domains resolve to the same IP
2. Ensure server is accessible at that IP
3. Configure Nginx (if not done)
4. Setup SSL certificates
5. Test domain access

For detailed instructions, see `DOCKER_EXPOSE_PUBLIC_URL.md`.

