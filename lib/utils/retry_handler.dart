import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

/// Smart retry handler that respects rate limits and uses exponential backoff
class RetryHandler {
  /// Execute a request with smart retry logic
  /// 
  /// - Respects `Retry-After` header from 429 responses
  /// - Uses exponential backoff for other errors
  /// - Doesn't count retries as new requests (waits before retrying)
  static Future<http.Response> executeWithRetry({
    required Future<http.Response> Function() request,
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 2),
    bool respectRateLimit = true,
  }) async {
    int attempt = 0;
    Duration delay = baseDelay;

    while (attempt <= maxRetries) {
      try {
        final response = await request();

        // Success - return immediately
        if (response.statusCode < 400) {
          return response;
        }

        // Rate limited (429) - respect Retry-After header
        if (response.statusCode == 429 && respectRateLimit) {
          if (attempt >= maxRetries) {
            throw ApiException(
              'Rate limit exceeded after $maxRetries retries',
              response.statusCode,
              response.body,
            );
          }

          // Check for Retry-After header
          final retryAfterHeader = response.headers['retry-after'];
          if (retryAfterHeader != null) {
            try {
              final retryAfterSeconds = int.parse(retryAfterHeader);
              delay = Duration(seconds: retryAfterSeconds);
            } catch (e) {
              // If parsing fails, use exponential backoff
              delay = Duration(seconds: baseDelay.inSeconds * (1 << attempt));
            }
          } else {
            // No Retry-After header, use exponential backoff
            delay = Duration(seconds: baseDelay.inSeconds * (1 << attempt));
          }

          // Wait before retrying (this prevents counting retry as new request)
          await Future.delayed(delay);
          attempt++;
          continue;
        }

        // Other 4xx/5xx errors - throw immediately (don't retry)
        if (response.statusCode >= 400) {
          throw ApiException(
            'Request failed with status ${response.statusCode}',
            response.statusCode,
            response.body,
          );
        }

        return response;
      } catch (e) {
        // If it's an ApiException, rethrow (already handled above)
        if (e is ApiException) {
          // For 429, we already handled retry logic above
          if (e.statusCode == 429 && attempt < maxRetries) {
            // This shouldn't happen, but just in case
            await Future.delayed(delay);
            attempt++;
            continue;
          }
          rethrow;
        }

        // Network errors - retry with exponential backoff
        final errorMsg = e.toString();
        final isNetworkError = errorMsg.contains('Connection refused') ||
            errorMsg.contains('Failed host lookup') ||
            errorMsg.contains('Network is unreachable') ||
            errorMsg.contains('SocketException') ||
            errorMsg.contains('TimeoutException');

        if (isNetworkError && attempt < maxRetries) {
          // Exponential backoff: 2s, 4s, 8s
          delay = Duration(seconds: baseDelay.inSeconds * (1 << attempt));
          await Future.delayed(delay);
          attempt++;
          continue;
        }

        // Max retries reached or non-retryable error
        rethrow;
      }
    }

    // Should never reach here, but just in case
    throw ApiException('Request failed after $maxRetries retries', 0, '');
  }

  /// Check if error is rate limit related
  static bool isRateLimitError(dynamic error) {
    if (error is ApiException) {
      return error.statusCode == 429;
    }
    if (error is String) {
      return error.contains('429') || 
             error.contains('rate limit') || 
             error.contains('Too many');
    }
    return false;
  }

  /// Extract retry delay from response headers
  static Duration? getRetryAfter(http.Response response) {
    final retryAfterHeader = response.headers['retry-after'];
    if (retryAfterHeader != null) {
      try {
        final seconds = int.parse(retryAfterHeader);
        return Duration(seconds: seconds);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

