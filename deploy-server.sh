#!/bin/bash

# Server Deployment Script for Exam Management App
# This script automates the deployment process

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Exam Management App - Server Deployment              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Variables
API_DOMAIN="exam-app-api.duckdns.org"
CHAT_DOMAIN="backend-chat.duckdns.org"
NGINX_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

echo -e "${GREEN}Step 1: Installing dependencies...${NC}"
apt update
apt install -y nginx certbot python3-certbot-nginx

echo -e "${GREEN}Step 2: Copying Nginx configurations...${NC}"
cp nginx/exam-app-api.duckdns.org.conf ${NGINX_DIR}/exam-app-api.duckdns.org
cp nginx/backend-chat.duckdns.org.conf ${NGINX_DIR}/backend-chat.duckdns.org

echo -e "${GREEN}Step 3: Enabling Nginx sites...${NC}"
ln -sf ${NGINX_DIR}/exam-app-api.duckdns.org ${NGINX_ENABLED_DIR}/
ln -sf ${NGINX_DIR}/backend-chat.duckdns.org ${NGINX_ENABLED_DIR}/

# Remove default site if exists
if [ -f "${NGINX_ENABLED_DIR}/default" ]; then
    rm ${NGINX_ENABLED_DIR}/default
fi

echo -e "${GREEN}Step 4: Testing Nginx configuration...${NC}"
nginx -t

echo -e "${GREEN}Step 5: Reloading Nginx...${NC}"
systemctl reload nginx

echo -e "${GREEN}Step 6: Setting up firewall...${NC}"
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw --force enable

echo -e "${YELLOW}Step 7: Building Docker containers...${NC}"
echo "Please ensure you have created .env files in backend-api/ and backend-chat/"
read -p "Press Enter to continue after creating .env files..."

docker-compose build

echo -e "${GREEN}Step 8: Starting Docker containers...${NC}"
docker-compose up -d

echo -e "${GREEN}Step 9: Waiting for containers to start...${NC}"
sleep 10

echo -e "${GREEN}Step 10: Checking container health...${NC}"
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API container is healthy${NC}"
else
    echo -e "${RED}✗ API container is not responding${NC}"
    docker-compose logs api
fi

if curl -f http://localhost:3001/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Chat container is healthy${NC}"
else
    echo -e "${RED}✗ Chat container is not responding${NC}"
    docker-compose logs chat
fi

echo ""
echo -e "${YELLOW}Step 11: SSL Certificate Setup${NC}"
echo "You need to obtain SSL certificates manually:"
echo "  sudo certbot --nginx -d ${API_DOMAIN}"
echo "  sudo certbot --nginx -d ${CHAT_DOMAIN}"
echo ""
read -p "Do you want to run Certbot now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    certbot --nginx -d ${API_DOMAIN}
    certbot --nginx -d ${CHAT_DOMAIN}
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Deployment Complete!                                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "API Endpoint: http://${API_DOMAIN}"
echo "Chat Endpoint: http://${CHAT_DOMAIN}"
echo ""
echo "Next steps:"
echo "1. Update .env files with HTTPS URLs in ALLOWED_ORIGINS"
echo "2. Restart containers: docker-compose restart"
echo "3. Update Flutter app with domain URLs"
echo "4. Build and distribute the app"
echo ""

