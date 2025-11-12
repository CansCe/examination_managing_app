import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching API responses to improve performance
class ApiCacheService {
  static const String _cachePrefix = 'api_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 5);
  
  /// Get cached data
  static Future<Map<String, dynamic>?> getCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('$_cachePrefix$key');
      
      if (cachedData == null) return null;
      
      final decoded = json.decode(cachedData) as Map<String, dynamic>;
      final timestamp = DateTime.parse(decoded['timestamp'] as String);
      final duration = Duration(
        milliseconds: decoded['duration'] as int? ?? _defaultCacheDuration.inMilliseconds,
      );
      
      // Check if cache is expired
      if (DateTime.now().difference(timestamp) > duration) {
        await prefs.remove('$_cachePrefix$key');
        return null;
      }
      
      return decoded['data'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
  
  /// Cache data with optional custom duration
  static Future<void> setCached(
    String key,
    Map<String, dynamic> data, {
    Duration? duration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'duration': (duration ?? _defaultCacheDuration).inMilliseconds,
      };
      
      await prefs.setString(
        '$_cachePrefix$key',
        json.encode(cacheData),
      );
    } catch (e) {
      // Silently fail - caching is not critical
    }
  }
  
  /// Cache list data
  static Future<List<Map<String, dynamic>>?> getCachedList(String key) async {
    final cached = await getCached(key);
    if (cached == null) return null;
    
    if (cached['items'] is List) {
      return (cached['items'] as List)
          .cast<Map<String, dynamic>>()
          .toList();
    }
    return null;
  }
  
  /// Cache list data
  static Future<void> setCachedList(
    String key,
    List<Map<String, dynamic>> items, {
    Duration? duration,
  }) async {
    await setCached(
      key,
      {'items': items},
      duration: duration,
    );
  }
  
  /// Clear specific cache
  static Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$key');
    } catch (e) {
      // Silently fail
    }
  }
  
  /// Clear all API caches
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (key) => key.startsWith(_cachePrefix),
      );
      
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Silently fail
    }
  }
  
  /// Invalidate cache for a pattern (e.g., all exam-related caches)
  static Future<void> invalidatePattern(String pattern) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (key) => key.startsWith('$_cachePrefix$pattern'),
      );
      
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Silently fail
    }
  }
}

