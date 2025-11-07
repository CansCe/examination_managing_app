import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      print('✓ Supabase initialized');
    } catch (e) {
      print('✗ Supabase initialization error: $e');
      rethrow;
    }
  }

  static SupabaseClient get client {
    if (!_initialized || _client == null) {
      throw Exception('Supabase not initialized. Call SupabaseService.initialize() first.');
    }
    return _client!;
  }

  static bool get isInitialized => _initialized;
}

