# Auto-Discovery API Setup Guide

## Overview

The app now supports **automatic API endpoint discovery**. When the app launches, it will automatically try multiple API endpoints and use the first one that responds. This means you don't need to configure the API URL at build time!

## How It Works

1. **On First Launch**: App tries a list of potential API endpoints
2. **Auto-Discovery**: First endpoint that responds is saved locally
3. **Future Launches**: App uses the saved endpoint (faster startup)
4. **Validation**: On each launch, the app validates the saved endpoint
5. **Fallback**: If saved endpoint fails, it rediscovers automatically

## Setting Up Your API Domains

### Option 1: Add Domains in Code (Recommended for Production)

Edit `lib/services/api_discovery_service.dart` and add your domains to the list:

```dart
static final List<String> _defaultApiUrls = [
  // Add your production domains here
  'https://api.yourdomain.com',
  'http://api.yourdomain.com',
  'https://yourapp.duckdns.org',
  'http://yourapp.duckdns.org',
  
  // Local development
  'http://localhost:3000',
  'http://10.0.2.2:3000',
];
```

### Option 2: Add Domains at Runtime

You can add custom domains when the app starts:

```dart
// In main.dart or your app initialization
ApiConfig.addCustomApiUrls([
  'https://api.yourdomain.com',
  'https://api2.yourdomain.com',
]);

ApiConfig.addCustomChatUrls([
  'https://chat.yourdomain.com',
  'https://chat2.yourdomain.com',
]);
```

### Option 3: User Manual Configuration

Users can manually configure the API URL in app settings if auto-discovery fails.

## Build the App

**No special build flags needed!** Just build normally:

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

The app will automatically discover available endpoints on first launch.

## Customization

### Add Your Domains

1. **Edit `api_discovery_service.dart`**:
   - Open `lib/services/api_discovery_service.dart`
   - Find `_defaultApiUrls` and `_defaultChatUrls`
   - Add your domain URLs to the list (in order of preference)

2. **Rebuild the app**:
   ```bash
   flutter build apk --release
   ```

### Priority Order

Domains are tried in the order they appear in the list:
- First domain in list = Highest priority
- Last domain in list = Lowest priority
- First responding domain = Used and saved

## Example Setup

### For DuckDNS (Free)

```dart
static final List<String> _defaultApiUrls = [
  'https://examapp.duckdns.org',
  'http://examapp.duckdns.org',
  'http://localhost:3000',
];
```

### For Custom Domain

```dart
static final List<String> _defaultApiUrls = [
  'https://api.exammanagement.com',
  'http://api.exammanagement.com',
  'https://examapp.duckdns.org',
  'http://localhost:3000',
];
```

### For Multiple Domains (Failover)

```dart
static final List<String> _defaultApiUrls = [
  'https://api-primary.yourdomain.com',  // Primary
  'https://api-backup.yourdomain.com',   // Backup
  'https://api-secondary.yourdomain.com', // Secondary
  'http://localhost:3000',                // Local fallback
];
```

## Testing

### Test Auto-Discovery

1. Clear app data (to reset stored URLs)
2. Launch the app
3. Check console logs for discovery process
4. App should automatically find and use working endpoint

### Check Current Configuration

```dart
print('Current API Config: ${ApiConfig.currentConfig}');
```

Output:
```
{
  'baseUrl': 'https://api.yourdomain.com',
  'chatBaseUrl': 'https://chat.yourdomain.com',
  'isProduction': 'true',
  'initialized': 'true'
}
```

## Troubleshooting

### No Endpoints Found

**Problem**: App can't find any working endpoints

**Solution**:
1. Check your domains are accessible
2. Verify `/health` endpoint is working
3. Check firewall/network settings
4. Add more domains to the discovery list

### Wrong Endpoint Selected

**Problem**: App selects wrong endpoint (e.g., localhost instead of production)

**Solution**:
1. Reorder domains in `_defaultApiUrls` (put production first)
2. Clear app data and restart
3. Use `ApiConfig.rediscover()` to force rediscovery

### Endpoint Stops Working

**Problem**: Saved endpoint stops working

**Solution**:
- App automatically rediscovers if saved endpoint fails
- Or manually trigger: `ApiConfig.rediscover()`

## Manual Configuration (For Users)

If auto-discovery fails, users can manually configure:

```dart
// Set API URL manually
await ApiConfig.setApiUrl('https://api.yourdomain.com');

// Set Chat URL manually
await ApiConfig.setChatUrl('https://chat.yourdomain.com');
```

## Advanced: Runtime Domain Addition

You can add domains at runtime (e.g., from server config):

```dart
// Add domains from remote config
final serverConfig = await fetchServerConfig();
ApiConfig.addCustomApiUrls(serverConfig.apiUrls);
ApiConfig.addCustomChatUrls(serverConfig.chatUrls);

// Force rediscovery with new domains
await ApiConfig.rediscover();
```

## Benefits

✅ **No build-time configuration needed**
✅ **Automatic failover** between domains
✅ **Works for all users** without setup
✅ **Fast startup** (uses cached URL)
✅ **Self-healing** (rediscovers if endpoint fails)
✅ **Easy to add new domains** (just update list)

## Security Notes

- Always use HTTPS for production endpoints
- The app validates endpoints by checking `/health`
- Stored URLs are saved locally (not sent anywhere)
- Users can manually override if needed

## Next Steps

1. **Add your domains** to `api_discovery_service.dart`
2. **Build the app** normally (no special flags)
3. **Test** on first launch
4. **Distribute** to users - they'll auto-connect!

The app will automatically discover and use your API endpoints! 🚀

