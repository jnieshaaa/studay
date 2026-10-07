import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration and lifecycle management for Supabase in Studay.
///
/// Reads credentials from `.env` with fallback to `--dart-define` environment
/// variables (`SUPABASE_URL` and `SUPABASE_ANON_KEY`).
///
/// Gracefully handles missing credentials or offline state so that local
/// study decks and mock exams continue working without internet or Supabase.
class SupabaseConfig {
  static bool _isInitialized = false;

  /// Whether Supabase client is actively initialized and available.
  static bool get isInitialized => _isInitialized;

  /// The configured Supabase project URL.
  static String get supabaseUrl {
    try {
      final fromDotenv = dotenv.env['SUPABASE_URL']?.trim() ?? '';
      if (fromDotenv.isNotEmpty) return fromDotenv;
    } catch (_) {}
    return const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  }

  /// The configured Supabase Anon public key.
  static String get supabaseAnonKey {
    try {
      final fromDotenv = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
      if (fromDotenv.isNotEmpty) return fromDotenv;
    } catch (_) {}
    return const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }

  /// Returns true if valid, non-placeholder credentials have been provided.
  static bool get isConfigured {
    final url = supabaseUrl;
    final key = supabaseAnonKey;
    if (url.isEmpty || key.isEmpty) return false;
    if (url.contains('your-project') ||
        url.contains('your-database') ||
        key.contains('your-anon')) {
      return false;
    }
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Safe access to the active SupabaseClient, or null if uninitialized.
  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initializes `.env` loading and connects to Supabase if configured.
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('[SupabaseConfig] .env file not loaded (optional): $e');
    }

    if (!isConfigured) {
      debugPrint(
        '[SupabaseConfig] Supabase is not configured yet. '
        'Add your SUPABASE_URL and SUPABASE_ANON_KEY to .env to connect.',
      );
      _isInitialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('[SupabaseConfig] Supabase connected successfully to $supabaseUrl');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[SupabaseConfig] Failed to initialize Supabase: $e');
    }
  }
}
