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
  static final List<String> _defaultApiUrls = [
    // ADD YOUR PRODUCTION DOMAINS HERE (uncomment and update):
    // 'https://api.yourdomain.com',
    // 'http://api.yourdomain.com',
    // 'https://yourapp.duckdns.org',
    // 'http://yourapp.duckdns.org',
    'http://exam-app-api.duckdns.org',
    // Local development (for testing)
    'http://localhost:3000',
    'http://10.0.2.2:3000', // Android emulator
  ];

  // List of potential Chat domains to try
  // 
  // TO ADD YOUR DOMAINS:
  // 1. Uncomment and update the examples below, OR
  // 2. Use addCustomChatUrls() at runtime
  // 3. Domains are tried in order (first one that responds is used)
  static final List<String> _defaultChatUrls = [
    // ADD YOUR PRODUCTION DOMAINS HERE (uncomment and update):
    // 'https://chat.yourdomain.com',
    // 'http://chat.yourdomain.com',
    // 'https://yourapp.duckdns.org',
    // 'http://yourapp.duckdns.org',
    'http://backend-chat.duckdns.org'
    // Local development
    'http://localhost:3001',
    'http://10.0.2.2:3001', // Android emulator
  ];

  /// Discover available API URL by trying multiple endpoints
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

        if (response.statusCode == 200) {
          print('  ✅ Found working API: $url');
          await _saveApiUrl(url);
          return url;
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

        if (response.statusCode == 200) {
          print('  ✅ Found working Chat: $url');
          await _saveChatUrl(url);
          return url;
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
      return response.statusCode == 200;
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
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get API URL with auto-discovery and fallback
  static Future<String> getApiUrl({
    bool forceRediscovery = false,
    List<String>? customUrls,
  }) async {
    // 1. Try stored URL first (if not forcing rediscovery)
    if (!forceRediscovery) {
      final storedUrl = await getStoredApiUrl();
      if (storedUrl != null) {
        final isValid = await validateStoredApiUrl();
        if (isValid) {
          print('✅ Using stored API URL: $storedUrl');
          return storedUrl;
        } else {
          print('⚠️ Stored API URL is invalid, rediscovering...');
        }
      }
    }

    // 2. Try to discover new URL
    final discoveredUrl = await discoverApiUrl(urlsToTry: customUrls);
    if (discoveredUrl != null) {
      return discoveredUrl;
    }

    // 3. Fallback to stored URL even if invalid (might work later)
    final storedUrl = await getStoredApiUrl();
    if (storedUrl != null) {
      print('⚠️ Using stored URL as fallback: $storedUrl');
      return storedUrl;
    }

    // 4. Ultimate fallback to localhost
    print('⚠️ No API URL found, using localhost fallback');
    return 'http://localhost:3000';
  }

  /// Get Chat URL with auto-discovery and fallback
  static Future<String> getChatUrl({
    bool forceRediscovery = false,
    List<String>? customUrls,
  }) async {
    // 1. Try stored URL first (if not forcing rediscovery)
    if (!forceRediscovery) {
      final storedUrl = await getStoredChatUrl();
      if (storedUrl != null) {
        final isValid = await validateStoredChatUrl();
        if (isValid) {
          print('✅ Using stored Chat URL: $storedUrl');
          return storedUrl;
        } else {
          print('⚠️ Stored Chat URL is invalid, rediscovering...');
        }
      }
    }

    // 2. Try to discover new URL
    final discoveredUrl = await discoverChatUrl(urlsToTry: customUrls);
    if (discoveredUrl != null) {
      return discoveredUrl;
    }

    // 3. Fallback to stored URL even if invalid (might work later)
    final storedUrl = await getStoredChatUrl();
    if (storedUrl != null) {
      print('⚠️ Using stored URL as fallback: $storedUrl');
      return storedUrl;
    }

    // 4. Ultimate fallback to localhost
    print('⚠️ No Chat URL found, using localhost fallback');
    return 'http://localhost:3001';
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

