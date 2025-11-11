import 'dart:developer' as developer;

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class Logger {
  static const bool _enableDebug = true; // Set to false in production
  static const bool _enableInfo = true;
  static const bool _enableWarning = true;
  static const bool _enableError = true;

  static void debug(String message, [String? tag]) {
    if (_enableDebug) {
      developer.log(
        message,
        name: tag ?? 'DEBUG',
        level: 100, // Debug level
      );
    }
  }

  static void info(String message, [String? tag]) {
    if (_enableInfo) {
      developer.log(
        message,
        name: tag ?? 'INFO',
        level: 200, // Info level
      );
    }
  }

  static void warning(String message, [String? tag]) {
    if (_enableWarning) {
      developer.log(
        message,
        name: tag ?? 'WARNING',
        level: 300, // Warning level
      );
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    if (_enableError) {
      developer.log(
        error != null ? '$message\nError: $error' : message,
        name: tag ?? 'ERROR',
        level: 400, // Error level
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void log(LogLevel level, String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    switch (level) {
      case LogLevel.debug:
        debug(message, tag);
        break;
      case LogLevel.info:
        info(message, tag);
        break;
      case LogLevel.warning:
        warning(message, tag);
        break;
      case LogLevel.error:
        Logger.error(message, error, stackTrace, tag);
        break;
    }
  }
}