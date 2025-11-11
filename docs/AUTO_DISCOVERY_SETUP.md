# API Auto-Discovery Setup

The Exam Management App includes an automatic API discovery feature that allows the Flutter app to automatically find and connect to available backend services without manual configuration.

## How It Works

The auto-discovery service:

1. **Tries multiple endpoints** in order (local first, then production)
2. **Tests each endpoint** by calling the `/health` endpoint
3. **Uses the first working endpoint** it finds
4. **Saves the endpoint** locally for future use
5. **Re-validates** on each app launch

## Default Endpoints

The app tries these endpoints in order:

### API Service (Main Backend)
- `http://localhost:3000` (local development)
- `http://10.0.2.2:3000` (Android emulator)
- `https://exam-app-api.duckdns.org` (production HTTPS)
- `http://exam-app-api.duckdns.org` (production HTTP fallback)

### Chat Service
- `http://localhost:3001` (local development)
- `http://10.0.2.2:3001` (Android emulator)
- `https://backend-chat.duckdns.org` (production HTTPS)
- `http://backend-chat.duckdns.org` (production HTTP fallback)

## Adding Your Own Domains

### Method 1: Edit Source Code (Recommended for Permanent Changes)

1. **Open the auto-discovery service file**
   ```
   lib/services/api_discovery_service.dart
   ```

2. **Find the default URL lists**
   ```dart
   static final List<String> _defaultApiUrls = [
     'http://localhost:3000',
     'http://10.0.2.2:3000',
     // Add your domains here
     'https://your-api-domain.com',
     'http://your-api-domain.com',
   ];
   
   static final List<String> _defaultChatUrls = [
     'http://localhost:3001',
     'http://10.0.2.2:3001',
     // Add your domains here
     'https://your-chat-domain.com',
     'http://your-chat-domain.com',
   ];
   ```

3. **Add your domains** (HTTPS first, then HTTP fallback)
   ```dart
   static final List<String> _defaultApiUrls = [
     'http://localhost:3000',
     'http://10.0.2.2:3000',
     'https://api.yourdomain.com',      // Your production API
     'http://api.yourdomain.com',        // HTTP fallback
     'https://exam-app-api.duckdns.org', // Existing production
     'http://exam-app-api.duckdns.org',
   ];
   ```

4. **Rebuild the app**
   ```bash
   flutter build apk --release
   # or
   flutter build ios --release
   ```

### Method 2: Runtime Configuration (For Testing)

You can also add custom URLs at runtime using the `ApiDiscoveryService`:

```dart
// Add custom URLs to try
await ApiDiscoveryService.addCustomApiUrls([
  'https://test-api.example.com',
  'http://test-api.example.com',
]);

await ApiDiscoveryService.addCustomChatUrls([
  'https://test-chat.example.com',
  'http://test-chat.example.com',
]);

// Discover with custom URLs
final apiUrl = await ApiDiscoveryService.discoverApiUrl();
final chatUrl = await ApiDiscoveryService.discoverChatUrl();
```

## How Discovery Works

### Discovery Process

1. **Check saved URL**: First checks if a URL was previously saved
2. **Validate saved URL**: Tests if saved URL still works
3. **Try default URLs**: If saved URL fails, tries default list
4. **Try custom URLs**: If provided, tries custom URLs
5. **Save working URL**: Saves the first working URL found

### Health Check

Each endpoint is tested by calling:
- API Service: `{url}/health`
- Chat Service: `{url}/health`

The endpoint must return HTTP 200 status code to be considered valid.

### Timeout

Default timeout is 3 seconds per endpoint. You can customize:

```dart
final apiUrl = await ApiDiscoveryService.discoverApiUrl(
  timeout: Duration(seconds: 5),
);
```

## Local Storage

Discovered URLs are saved using `SharedPreferences`:

- **API URL Key**: `api_base_url`
- **Chat URL Key**: `chat_base_url`
- **Last Checked**: Timestamps for when URLs were last validated

### Clearing Saved URLs

To force re-discovery, clear saved URLs:

```dart
await ApiDiscoveryService.clearSavedUrls();
```

## Android Emulator Support

The app automatically tries `10.0.2.2` which maps to the host machine's localhost when running on Android emulator. This is included in the default URL list.

## Production Deployment

### For Production Apps

1. **Add your production domains** to the default URL list
2. **Place HTTPS URLs first** (more secure)
3. **Include HTTP fallback** (in case HTTPS fails)
4. **Test discovery** before releasing

### Example Production Configuration

```dart
static final List<String> _defaultApiUrls = [
  // Production (HTTPS first)
  'https://api.yourdomain.com',
  'https://exam-app-api.duckdns.org',
  
  // Production fallback (HTTP)
  'http://api.yourdomain.com',
  'http://exam-app-api.duckdns.org',
  
  // Development (only for debug builds)
  if (kDebugMode) 'http://localhost:3000',
  if (kDebugMode) 'http://10.0.2.2:3000',
];
```

## Debugging

### Enable Debug Logs

The discovery service prints detailed logs:

```
🔍 Starting API URL discovery...
📋 Trying 4 potential endpoints
  ⏳ Testing: http://localhost:3000
  ✅ Found working API: http://localhost:3000
```

### Check Saved URLs

```dart
final savedApiUrl = await ApiDiscoveryService.getSavedApiUrl();
final savedChatUrl = await ApiDiscoveryService.getSavedChatUrl();
print('Saved API URL: $savedApiUrl');
print('Saved Chat URL: $savedChatUrl');
```

### Force Re-Discovery

```dart
// Clear saved URLs
await ApiDiscoveryService.clearSavedUrls();

// Discover again
final apiUrl = await ApiDiscoveryService.discoverApiUrl();
```

## Troubleshooting

### App Can't Find Backend

- **Check backend is running**: Ensure services are started
- **Check health endpoint**: Verify `/health` returns 200
- **Check network**: Ensure device can reach backend
- **Check logs**: Look for discovery logs in console
- **Try manual URL**: Use `ApiConfig.setBaseUrl()` to set manually

### Wrong Endpoint Selected

- **Clear saved URLs**: Force re-discovery
- **Reorder URL list**: Put preferred URL first
- **Check network**: Ensure preferred endpoint is reachable

### Discovery Takes Too Long

- **Reduce timeout**: Lower timeout value
- **Remove slow URLs**: Remove unreachable URLs from list
- **Check network**: Ensure network connection is stable

## Best Practices

1. **HTTPS First**: Always try HTTPS before HTTP
2. **Local First**: Try localhost before remote (for development)
3. **Fallback URLs**: Include HTTP fallback for HTTPS URLs
4. **Test Discovery**: Test discovery on all target platforms
5. **Monitor Logs**: Check discovery logs in production
6. **Update Domains**: Keep domain list updated when infrastructure changes

## Manual Override

If auto-discovery fails, you can manually set URLs:

```dart
// In your app initialization
await ApiConfig.setBaseUrl('https://api.yourdomain.com');
await ApiConfig.setChatBaseUrl('https://chat.yourdomain.com');
```

However, auto-discovery is recommended as it provides better flexibility and user experience.

---

**Last Updated**: 2024