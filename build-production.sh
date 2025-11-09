#!/bin/bash

# Production Build Script for Exam Management App
# 
# Usage:
#   ./build-production.sh [platform] [api_url] [chat_url]
#
# Examples:
#   ./build-production.sh android https://api.yourdomain.com https://chat.yourdomain.com
#   ./build-production.sh ios https://api.yourdomain.com https://chat.yourdomain.com
#   ./build-production.sh apk http://192.168.1.100:3000 http://192.168.1.100:3001

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PLATFORM="${1:-android}"
API_URL="${2:-https://api.yourdomain.com}"
CHAT_URL="${3:-https://chat.yourdomain.com}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Production Build Script                            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Platform:${NC} $PLATFORM"
echo -e "${GREEN}API URL:${NC} $API_URL"
echo -e "${GREEN}Chat URL:${NC} $CHAT_URL"
echo ""

# Validate URLs
if [[ ! "$API_URL" =~ ^https?:// ]]; then
    echo -e "${RED}Error: API URL must start with http:// or https://${NC}"
    exit 1
fi

if [[ ! "$CHAT_URL" =~ ^https?:// ]]; then
    echo -e "${RED}Error: Chat URL must start with http:// or https://${NC}"
    exit 1
fi

# Build based on platform
case "$PLATFORM" in
    android|apk)
        echo -e "${YELLOW}Building Android APK...${NC}"
        flutter build apk --release \
            --dart-define=API_BASE_URL="$API_URL" \
            --dart-define=CHAT_BASE_URL="$CHAT_URL"
        echo -e "${GREEN}✓ APK built successfully!${NC}"
        echo -e "${GREEN}Output: build/app/outputs/flutter-apk/app-release.apk${NC}"
        ;;
    appbundle|bundle)
        echo -e "${YELLOW}Building Android App Bundle...${NC}"
        flutter build appbundle --release \
            --dart-define=API_BASE_URL="$API_URL" \
            --dart-define=CHAT_BASE_URL="$CHAT_URL"
        echo -e "${GREEN}✓ App Bundle built successfully!${NC}"
        echo -e "${GREEN}Output: build/app/outputs/bundle/release/app-release.aab${NC}"
        ;;
    ios)
        echo -e "${YELLOW}Building iOS...${NC}"
        flutter build ios --release \
            --dart-define=API_BASE_URL="$API_URL" \
            --dart-define=CHAT_BASE_URL="$CHAT_URL"
        echo -e "${GREEN}✓ iOS build completed!${NC}"
        echo -e "${YELLOW}Note: Open Xcode to archive and distribute${NC}"
        ;;
    *)
        echo -e "${RED}Error: Unknown platform '$PLATFORM'${NC}"
        echo -e "${YELLOW}Supported platforms: android, apk, appbundle, bundle, ios${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo ""
echo -e "${BLUE}Configuration used:${NC}"
echo -e "  API URL: $API_URL"
echo -e "  Chat URL: $CHAT_URL"
echo ""

