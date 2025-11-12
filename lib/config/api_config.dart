import 'package:exam_management_app/services/api_discovery_service.dart';

/// API Configuration for the Exam Management App
/// 
/// This class supports multiple configuration methods (in priority order):
/// 1. Runtime auto-discovery (automatically finds available API endpoints)
/// 2. Build-time configuration via --dart-define
/// 3. Stored configuration from previous sessions
/// 4. Default values for local development
/// 
/// AUTO-DISCOVERY:
/// The app will automatically try multiple API endpoints and use the first one that responds.
/// Once found, it's stored locally and reused in future sessions.
/// 
/// Configuration Guide:
/// ====================
/// 
/// AUTOMATIC (Recommended):
/// - App automatically discovers available API endpoints on first launch
/// - Stores the working URL locally for future use
/// - Re-validates on app startup
/// - Automatically upgrades HTTP URLs to HTTPS when available
/// 
/// BUILD-TIME (Optional):
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://api.yourdomain.com \
///   --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
/// 
/// MANUAL CONFIGURATION:
/// Users can manually configure API URL in app settings if auto-discovery fails
/// 
/// HTTPS UPGRADE:
/// - App automatically detects HTTP to HTTPS redirects
/// - Upgrades stored HTTP URLs to HTTPS when server redirects
/// - Prioritizes HTTPS URLs for production domains
/// 
/// See PRODUCTION_DEPLOYMENT.md and HTTPS_UPGRADE.md for detailed instructions
class ApiConfig {
  static String? _cachedApiUrl;
  static String? _cachedChatUrl;
  static bool _initialized = false;

  /// Initialize API configuration (call this on app startup)
  /// This will auto-discover available API endpoints if not already configured
  static Future<void> initialize({bool forceRediscovery = false}) async {
    if (_initialized && !forceRediscovery) {
      return;
    }

    print(' Initializing API Configuration...');
    
    // Get API URL with auto-discovery
    _cachedApiUrl = await ApiDiscoveryService.getApiUrl(
      forceRediscovery: forceRediscovery,
    );
    
    // Get Chat URL with auto-discovery
    _cachedChatUrl = await ApiDiscoveryService.getChatUrl(
      forceRediscovery: forceRediscovery,
    );
    
    _initialized = true;
    print('✅ API Configuration initialized');
    print('   API URL: $_cachedApiUrl');
    print('   Chat URL: $_cachedChatUrl');
  }

  /// Main API URL (MongoDB backend)
  /// 
  /// Priority order:
  /// 1. Build-time configuration (--dart-define)
  /// 2. Cached discovered URL
  /// 3. Stored URL from previous session
  /// 4. Localhost fallback
  static String get baseUrl {
    // 1. Try build-time configuration first (highest priority)
    const envApiUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    
    if (envApiUrl.isNotEmpty) {
      return envApiUrl;
    }
    
    // 2. Use cached URL if available
    if (_cachedApiUrl != null) {
      return _cachedApiUrl!;
    }
    
    // 3. Try to get stored URL (synchronous fallback)
    // Note: This is a fallback, initialize() should be called first
    return 'http://localhost:3000';
  }
  
  /// Chat Service URL (MongoDB + Socket.io WebSockets)
  /// 
  /// Priority order:
  /// 1. Build-time configuration (--dart-define)
  /// 2. Cached discovered URL
  /// 3. Stored URL from previous session
  /// 4. Localhost fallback
  /// 
  /// Note: WebSocket URL is automatically derived (ws:// or wss://)
  /// - http://localhost:3001 → ws://localhost:3001
  /// - https://chat.yourdomain.com → wss://chat.yourdomain.com
  static String get chatBaseUrl {
    // 1. Try build-time configuration first (highest priority)
    const envChatUrl = String.fromEnvironment(
      'CHAT_BASE_URL',
      defaultValue: '',
    );
    
    if (envChatUrl.isNotEmpty) {
      return envChatUrl;
    }
    
    // 2. Use cached URL if available
    if (_cachedChatUrl != null) {
      return _cachedChatUrl!;
    }
    
    // 3. Try to get stored URL (synchronous fallback)
    // Note: This is a fallback, initialize() should be called first
    return 'http://localhost:3001';
  }
  
  /// Get API URL asynchronously (with auto-discovery)
  /// Use this when you need the most up-to-date URL
  static Future<String> getBaseUrlAsync({bool forceRediscovery = false}) async {
    // 1. Check build-time config
    const envApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envApiUrl.isNotEmpty) {
      return envApiUrl;
    }
    
    // 2. Get from discovery service (with auto-discovery)
    final url = await ApiDiscoveryService.getApiUrl(
      forceRediscovery: forceRediscovery,
    );
    _cachedApiUrl = url;
    return url;
  }

  /// Get Chat URL asynchronously (with auto-discovery)
  /// Use this when you need the most up-to-date URL
  static Future<String> getChatBaseUrlAsync({bool forceRediscovery = false}) async {
    // 1. Check build-time config
    const envChatUrl = String.fromEnvironment('CHAT_BASE_URL', defaultValue: '');
    if (envChatUrl.isNotEmpty) {
      return envChatUrl;
    }
    
    // 2. Get from discovery service (with auto-discovery)
    final url = await ApiDiscoveryService.getChatUrl(
      forceRediscovery: forceRediscovery,
    );
    _cachedChatUrl = url;
    return url;
  }

  /// Manually set API URL (for user configuration)
  static Future<bool> setApiUrl(String url) async {
    final success = await ApiDiscoveryService.setApiUrl(url);
    if (success) {
      _cachedApiUrl = url;
    }
    return success;
  }

  /// Manually set Chat URL (for user configuration)
  static Future<bool> setChatUrl(String url) async {
    final success = await ApiDiscoveryService.setChatUrl(url);
    if (success) {
      _cachedChatUrl = url;
    }
    return success;
  }

  /// Add custom URLs to the discovery list
  static void addCustomApiUrls(List<String> urls) {
    ApiDiscoveryService.addCustomApiUrls(urls);
  }

  /// Add custom Chat URLs to the discovery list
  static void addCustomChatUrls(List<String> urls) {
    ApiDiscoveryService.addCustomChatUrls(urls);
  }

  /// Force rediscovery of API endpoints
  static Future<void> rediscover() async {
    await initialize(forceRediscovery: true);
  }

  /// Check if the app is configured for production
  static bool get isProduction {
    const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const chatUrl = String.fromEnvironment('CHAT_BASE_URL', defaultValue: '');
    final currentApi = baseUrl;
    final currentChat = chatBaseUrl;
    
    // Consider it production if:
    // 1. Build-time config is set, OR
    // 2. Current URLs are not localhost
    return apiUrl.isNotEmpty || 
           chatUrl.isNotEmpty ||
           (!currentApi.contains('localhost') && !currentApi.contains('10.0.2.2')) ||
           (!currentChat.contains('localhost') && !currentChat.contains('10.0.2.2'));
  }
  
  /// Get current configuration (for debugging)
  static Map<String, String> get currentConfig {
    return {
      'baseUrl': baseUrl,
      'chatBaseUrl': chatBaseUrl,
      'isProduction': isProduction.toString(),
      'initialized': _initialized.toString(),
    };
  }

  /// Clear stored configuration (for testing or reset)
  static Future<void> clearConfiguration() async {
    await ApiDiscoveryService.clearStoredUrls();
    _cachedApiUrl = null;
    _cachedChatUrl = null;
    _initialized = false;
  }
}

