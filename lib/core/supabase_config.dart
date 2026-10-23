import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized configuration and error mapping for Supabase Authentication.
class SupabaseConfig {
  /// Supabase project URL from `.env`.
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  /// Supabase client publishable / anon key from `.env`.
  static String get publishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      dotenv.env['SUPABASE_ANON_KEY'] ??
      '';

  /// Optional custom redirect URL from `.env` for email confirmation links.
  /// If unset, Supabase uses the Site URL configured in the Supabase Dashboard.
  static String? get emailRedirectTo {
    final redirect = dotenv.env['SUPABASE_REDIRECT_URL'];
    if (redirect != null && redirect.trim().isNotEmpty) {
      return redirect.trim();
    }
    return null;
  }

  /// Verifies that the required environment variables are set and non-empty.
  static bool get isValid => url.isNotEmpty && publishableKey.isNotEmpty;
}

/// Formatter that maps Supabase Auth errors to clear, actionable, user-facing messages.
class AuthErrorFormatter {
  /// Translates an [AuthException] into a descriptive user message.
  static String format(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final message = e.message.toLowerCase();
    final status = e.statusCode ?? '';

    // Database error in auth.users trigger
    if (code == 'unexpected_failure' ||
        message.contains('database error saving new user')) {
      return 'Database error: Could not save your user profile. The server-side profile trigger failed. Please ensure migrations in supabase/schema.sql are applied.';
    }

    // Email rate limit
    if (status == '429' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        message.contains('rate limit')) {
      return 'Email rate limit exceeded. Please wait 60 seconds before retrying.';
    }

    // Account already exists
    if (code == 'user_already_exists' ||
        message.contains('already registered') ||
        message.contains('already exists')) {
      return 'An account with this email already exists. Please sign in or use password recovery.';
    }

    // Expired or already consumed OTP / link
    if (code == 'otp_expired' ||
        message.contains('otp_expired') ||
        message.contains('expired') ||
        message.contains('invalid or has expired')) {
      return 'The verification link has expired or has already been used. Please request a new confirmation email or try signing in.';
    }

    // Weak password
    if (code == 'weak_password' || message.contains('weak password')) {
      return 'Password does not meet security requirements.';
    }

    // Invalid credentials
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return 'Invalid email or password. Please verify and try again.';
    }

    // Email not confirmed
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'Your email address has not been confirmed yet. Please check your inbox or request a new confirmation link.';
    }

    // Network / Socket error
    if (message.contains('connection refused') ||
        message.contains('socketexception') ||
        message.contains('network is unreachable')) {
      return 'Network connection error. Please check your internet connection and try again.';
    }

    // Default to Supabase message
    return e.message.isNotEmpty
        ? e.message
        : 'An authentication error occurred. Please try again.';
  }
}
