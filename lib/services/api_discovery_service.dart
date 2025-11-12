import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for auto-discovering available API endpoints
class ApiDiscoveryService {
  static const String _apiUrlKey = 'api_base_url';
  static const String _chatUrlKey = 'chat_base_url';
  static const String _apiUrlLastCheckedKey = 'api_url_last_checked';
  static const String _chatUrlLastCheckedKey = 'chat_url_last_checked';

  // List of potential API domains to try
  // These will be tried in order until one responds
  // 
  // TO ADD YOUR DOMAINS:
  // 1. Uncomment and update the examples below, OR
  // 2. Use addCustomApiUrls() at runtime
  // 3. Domains are tried in order (first one that responds is used)
  // 
  // PRIORITY ORDER:
  // 1. Local development (localhost) - for development
  // 2. HTTPS production URLs - secure production connections
  // 3. HTTP production URLs - fallback only (should redirect to HTTPS)
  static final List<String> _defaultApiUrls = [
    // Local development (tried first for development convenience)
    'http://localhost:3000',
    'http://10.0.2.2:3000', // Android emulator
    // Production domains (HTTPS first for security, HTTP as fallback)
    'https://exam-app-api.duckdns.org',
    'http://exam-app-api.duckdns.org', // Fallback (will redirect to HTTPS if configured)
  ];

  // List of potential Chat domains to try
  // Same priority order as API URLs
  static final List<String> _defaultChatUrls = [
    // Local development (tried first for development convenience)
    'http://localhost:3001',
    'http://10.0.2.2:3001', // Android emulator
    // Production domains (HTTPS first for security, HTTP as fallback)
    'https://backend-chat.duckdns.org',
    'http://backend-chat.duckdns.org', // Fallback (will redirect to HTTPS if configured)
  ];

  /// Discover available API URL by trying multiple endpoints
  /// Automatically handles HTTP to HTTPS redirects
  static Future<String?> discoverApiUrl({
    List<String>? urlsToTry,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final urls = urlsToTry ?? _defaultApiUrls;
    
    print('🔍 Starting API URL discovery...');
    print('📋 Trying ${urls.length} potential endpoints');

    for (final url in urls) {
      try {
        print('  ⏳ Testing: $url');
        final healthUrl = '$url/health';
        
        final response = await http
            .get(Uri.parse(healthUrl))
            .timeout(timeout);

        // Accept 200 (OK) or handle redirects to HTTPS
        if (response.statusCode == 200) {
          print('  ✅ Found working API: $url');
          await _saveApiUrl(url);
          return url;
        } else if (response.statusCode == 301 || response.statusCode == 302) {
          // HTTP redirects to HTTPS - use the HTTPS URL
          final location = response.headers['location'];
          if (location != null && location.startsWith('https://')) {
            final httpsUrl = location.replaceFirst('/health', '');
            print('  🔒 HTTP redirects to HTTPS: $httpsUrl');
            // Verify HTTPS URL works
            try {
              final httpsResponse = await http
                  .get(Uri.parse(location))
                  .timeout(timeout);
              if (httpsResponse.statusCode == 200) {
                print('  ✅ Verified HTTPS URL: $httpsUrl');
                await _saveApiUrl(httpsUrl);
                return httpsUrl;
              }
            } catch (e) {
              print('  ⚠️ HTTPS verification failed: $e');
            }
          }
        }
      } catch (e) {
        print('  ❌ Failed: $url - ${e.toString()}');
        continue;
      }
    }

    print('⚠️ No working API URL found');
    return null;
  }

  /// Discover available Chat URL by trying multiple endpoints
  /// Automatically handles HTTP to HTTPS redirects
  static Future<String?> discoverChatUrl({
    List<String>? urlsToTry,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final urls = urlsToTry ?? _defaultChatUrls;
    
    print('🔍 Starting Chat URL discovery...');
    print('📋 Trying ${urls.length} potential endpoints');

    for (final url in urls) {
      try {
        print('  ⏳ Testing: $url');
        final healthUrl = '$url/health';
        
        final response = await http
            .get(Uri.parse(healthUrl))
            .timeout(timeout);

        // Accept 200 (OK) or handle redirects to HTTPS
        if (response.statusCode == 200) {
          print('  ✅ Found working Chat: $url');
          await _saveChatUrl(url);
          return url;
        } else if (response.statusCode == 301 || response.statusCode == 302) {
          // HTTP redirects to HTTPS - use the HTTPS URL
          final location = response.headers['location'];
          if (location != null && location.startsWith('https://')) {
            final httpsUrl = location.replaceFirst('/health', '');
            print('  🔒 HTTP redirects to HTTPS: $httpsUrl');
            // Verify HTTPS URL works
            try {
              final httpsResponse = await http
                  .get(Uri.parse(location))
                  .timeout(timeout);
              if (httpsResponse.statusCode == 200) {
                print('  ✅ Verified HTTPS URL: $httpsUrl');
                await _saveChatUrl(httpsUrl);
                return httpsUrl;
              }
            } catch (e) {
              print('  ⚠️ HTTPS verification failed: $e');
            }
          }
        }
      } catch (e) {
        print('  ❌ Failed: $url - ${e.toString()}');
        continue;
      }
    }

    print('⚠️ No working Chat URL found');
    return null;
  }

  /// Get stored API URL from local storage
  static Future<String?> getStoredApiUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_apiUrlKey);
    } catch (e) {
      print('Error getting stored API URL: $e');
      return null;
    }
  }

  /// Get stored Chat URL from local storage
  static Future<String?> getStoredChatUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_chatUrlKey);
    } catch (e) {
      print('Error getting stored Chat URL: $e');
      return null;
    }
  }

  /// Save API URL to local storage
  static Future<void> _saveApiUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiUrlKey, url);
      await prefs.setInt(_apiUrlLastCheckedKey, DateTime.now().millisecondsSinceEpoch);
      print('💾 Saved API URL: $url');
    } catch (e) {
      print('Error saving API URL: $e');
    }
  }

  /// Save Chat URL to local storage
  static Future<void> _saveChatUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatUrlKey, url);
      await prefs.setInt(_chatUrlLastCheckedKey, DateTime.now().millisecondsSinceEpoch);
      print('💾 Saved Chat URL: $url');
    } catch (e) {
      print('Error saving Chat URL: $e');
    }
  }

  /// Manually set API URL (for user configuration)
  static Future<bool> setApiUrl(String url) async {
    try {
      // Validate URL by checking health endpoint
      final healthUrl = '$url/health';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await _saveApiUrl(url);
        return true;
      }
      return false;
    } catch (e) {
      print('Error setting API URL: $e');
      return false;
    }
  }

  /// Manually set Chat URL (for user configuration)
  static Future<bool> setChatUrl(String url) async {
    try {
      // Validate URL by checking health endpoint
      final healthUrl = '$url/health';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await _saveChatUrl(url);
        return true;
      }
      return false;
    } catch (e) {
      print('Error setting Chat URL: $e');
      return false;
    }
  }

  /// Clear stored URLs (for testing or reset)
  static Future<void> clearStoredUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiUrlKey);
      await prefs.remove(_chatUrlKey);
      await prefs.remove(_apiUrlLastCheckedKey);
      await prefs.remove(_chatUrlLastCheckedKey);
      print('🗑️ Cleared stored URLs');
    } catch (e) {
      print('Error clearing stored URLs: $e');
    }
  }

  /// Check if stored URL is still valid
  static Future<bool> validateStoredApiUrl() async {
    final storedUrl = await getStoredApiUrl();
    if (storedUrl == null) return false;

    try {
      final healthUrl = '$storedUrl/health';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 3));
      
      // Accept 200 (OK) or 301/302 (redirect to HTTPS)
      if (response.statusCode == 200) {
        return true;
      }
      
      // If HTTP redirects to HTTPS, try the HTTPS version
      if (response.statusCode == 301 || response.statusCode == 302) {
        final location = response.headers['location'];
        if (location != null && location.startsWith('https://')) {
          print('🔄 HTTP redirects to HTTPS, upgrading stored URL...');
          await _saveApiUrl(location.replaceFirst('/health', ''));
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if stored Chat URL is still valid
  static Future<bool> validateStoredChatUrl() async {
    final storedUrl = await getStoredChatUrl();
    if (storedUrl == null) return false;

    try {
      final healthUrl = '$storedUrl/health';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 3));
      
      // Accept 200 (OK) or 301/302 (redirect to HTTPS)
      if (response.statusCode == 200) {
        return true;
      }
      
      // If HTTP redirects to HTTPS, try the HTTPS version
      if (response.statusCode == 301 || response.statusCode == 302) {
        final location = response.headers['location'];
        if (location != null && location.startsWith('https://')) {
          print('🔄 HTTP redirects to HTTPS, upgrading stored URL...');
          await _saveChatUrl(location.replaceFirst('/health', ''));
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get API URL with auto-discovery and fallback
  /// Priority: localhost > HTTPS > HTTP
  /// Automatically upgrades HTTP URLs to HTTPS if server redirects
  static Future<String> getApiUrl({
    bool forceRediscovery = false,
    List<String>? customUrls,
  }) async {
    // 1. First, check if localhost is available (highest priority)
    if (!forceRediscovery) {
      final localhostUrls = ['http://localhost:3000', 'http://10.0.2.2:3000'];
      for (final localhostUrl in localhostUrls) {
        try {
          final healthUrl = '$localhostUrl/health';
          final response = await http
              .get(Uri.parse(healthUrl))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            print('✅ Localhost available, using: $localhostUrl');
            await _saveApiUrl(localhostUrl);
            return localhostUrl;
          }
        } catch (e) {
          // Localhost not available, continue
        }
      }
    }

    // 2. Try stored URL (if not forcing rediscovery and not localhost)
    if (!forceRediscovery) {
      final storedUrl = await getStoredApiUrl();
      if (storedUrl != null && !_isLocalhost(storedUrl)) {
        final isValid = await validateStoredApiUrl();
        if (isValid) {
          // Check if stored URL is HTTP and should be upgraded to HTTPS
          if (storedUrl.startsWith('http://') && !_isLocalhost(storedUrl)) {
            final httpsUrl = storedUrl.replaceFirst('http://', 'https://');
            print('🔒 Attempting HTTPS upgrade: $httpsUrl');
            try {
              final healthUrl = '$httpsUrl/health';
              final response = await http
                  .get(Uri.parse(healthUrl))
                  .timeout(const Duration(seconds: 3));
              if (response.statusCode == 200) {
                print('✅ Upgraded to HTTPS: $httpsUrl');
                await _saveApiUrl(httpsUrl);
                return httpsUrl;
              }
            } catch (e) {
              print('⚠️ HTTPS upgrade failed, using stored HTTP URL');
            }
          }
          print('✅ Using stored API URL: $storedUrl');
          return storedUrl;
        } else {
          print('⚠️ Stored API URL is invalid, rediscovering...');
        }
      }
    }

    // 3. Try to discover new URL (with priority: localhost > HTTPS > HTTP)
    final discoveredUrl = await discoverApiUrl(urlsToTry: customUrls);
    if (discoveredUrl != null) {
      return discoveredUrl;
    }

    // 4. Fallback to stored URL even if invalid (might work later)
    final storedUrl = await getStoredApiUrl();
    if (storedUrl != null) {
      print('⚠️ Using stored URL as fallback: $storedUrl');
      return storedUrl;
    }

    // 5. Ultimate fallback to localhost
    print('⚠️ No API URL found, using localhost fallback');
    return 'http://localhost:3000';
  }

  /// Get Chat URL with auto-discovery and fallback
  /// Priority: localhost > HTTPS > HTTP
  /// Automatically upgrades HTTP URLs to HTTPS if server redirects
  static Future<String> getChatUrl({
    bool forceRediscovery = false,
    List<String>? customUrls,
  }) async {
    // 1. First, check if localhost is available (highest priority)
    if (!forceRediscovery) {
      final localhostUrls = ['http://localhost:3001', 'http://10.0.2.2:3001'];
      for (final localhostUrl in localhostUrls) {
        try {
          final healthUrl = '$localhostUrl/health';
          final response = await http
              .get(Uri.parse(healthUrl))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            print('✅ Localhost available, using: $localhostUrl');
            await _saveChatUrl(localhostUrl);
            return localhostUrl;
          }
        } catch (e) {
          // Localhost not available, continue
        }
      }
    }

    // 2. Try stored URL (if not forcing rediscovery and not localhost)
    if (!forceRediscovery) {
      final storedUrl = await getStoredChatUrl();
      if (storedUrl != null && !_isLocalhost(storedUrl)) {
        final isValid = await validateStoredChatUrl();
        if (isValid) {
          // Check if stored URL is HTTP and should be upgraded to HTTPS
          if (storedUrl.startsWith('http://') && !_isLocalhost(storedUrl)) {
            final httpsUrl = storedUrl.replaceFirst('http://', 'https://');
            print('🔒 Attempting HTTPS upgrade: $httpsUrl');
            try {
              final healthUrl = '$httpsUrl/health';
              final response = await http
                  .get(Uri.parse(healthUrl))
                  .timeout(const Duration(seconds: 3));
              if (response.statusCode == 200) {
                print('✅ Upgraded to HTTPS: $httpsUrl');
                await _saveChatUrl(httpsUrl);
                return httpsUrl;
              }
            } catch (e) {
              print('⚠️ HTTPS upgrade failed, using stored HTTP URL');
            }
          }
          print('✅ Using stored Chat URL: $storedUrl');
          return storedUrl;
        } else {
          print('⚠️ Stored Chat URL is invalid, rediscovering...');
        }
      }
    }

    // 3. Try to discover new URL (with priority: localhost > HTTPS > HTTP)
    final discoveredUrl = await discoverChatUrl(urlsToTry: customUrls);
    if (discoveredUrl != null) {
      return discoveredUrl;
    }

    // 4. Fallback to stored URL even if invalid (might work later)
    final storedUrl = await getStoredChatUrl();
    if (storedUrl != null) {
      print('⚠️ Using stored URL as fallback: $storedUrl');
      return storedUrl;
    }

    // 5. Ultimate fallback to localhost
    print('⚠️ No Chat URL found, using localhost fallback');
    return 'http://localhost:3001';
  }

  /// Check if URL is localhost
  static bool _isLocalhost(String url) {
    return url.contains('localhost') || url.contains('10.0.2.2') || url.contains('127.0.0.1');
  }

  /// Add custom URLs to the discovery list
  static void addCustomApiUrls(List<String> urls) {
    _defaultApiUrls.insertAll(0, urls);
  }

  /// Add custom Chat URLs to the discovery list
  static void addCustomChatUrls(List<String> urls) {
    _defaultChatUrls.insertAll(0, urls);
  }
}

