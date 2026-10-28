import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_config.dart';
import '../models/app_user.dart';

/// Exception thrown when an email-triggering action is initiated while another is in progress.
class DuplicateRequestException implements Exception {
  final String message;

  const DuplicateRequestException([
    this.message = 'A request is already being processed. Please wait a moment before trying again.',
  ]);

  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient? _customClient;

  AuthService({SupabaseClient? client}) : _customClient = client;

  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  // In-flight concurrency lock to prevent accidental double-clicks and redundant calls
  static bool _isEmailActionInProgress = false;

  /// True if an email-triggering auth request is actively in-flight.
  static bool get isEmailActionInProgress => _isEmailActionInProgress;

  /// Translates raw auth and Supabase exceptions into human-friendly, production-level guidance.
  /// Handles `over_email_send_rate_limit` (HTTP 429), unconfirmed emails, and non-existent/invalid accounts.
  static String parseAuthErrorMessage(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('over_email_send_rate_limit') ||
        str.contains('email rate limit') ||
        str.contains('429') ||
        str.contains('too many requests') ||
        str.contains('rate limit')) {
      return 'Email delivery rate limit reached (2-4 emails/hr quota exceeded). Please wait before retrying or use custom Send Email Hook.';
    }
    if (str.contains('email not confirmed')) {
      return 'Email address is not yet confirmed. Your email address is not verified yet. Please check your inbox and verify your email before logging in.';
    }
    if (str.contains('invalid login credentials') ||
        str.contains('invalid_grant') ||
        str.contains('user not found')) {
      return 'Invalid email or password. Account does not exist or invalid password. Please check your email and password or create an account.';
    }
    if (str.contains('user already registered') ||
        str.contains('already been registered') ||
        str.contains('user_already_exists')) {
      return 'An account with this email address already exists. Please sign in or use password recovery.';
    }
    if (str.contains('network') ||
        str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('connection refused')) {
      return 'Network connection error. Please verify your internet connection and try again.';
    }
    return 'Authentication error: $error';
  }

  /// Sanitizes client-supplied signup metadata by stripping any attempted role elevation parameters.
  /// Public self-signups are strictly prevented from supplying an unapproved 'admin' role.
  static Map<String, dynamic>? sanitizeSignupMetadata(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized['role'] == 'admin') {
      sanitized.remove('role');
    }
    sanitized.remove('is_admin');
    return sanitized;
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends a password reset email using Supabase Auth with in-flight duplicate-click protection.
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    if (_isEmailActionInProgress) {
      throw const DuplicateRequestException(
        'A password recovery request is already being processed. Please wait a moment.',
      );
    }
    _isEmailActionInProgress = true;
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo ?? SupabaseConfig.emailRedirectTo,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(parseAuthErrorMessage(e));
    } finally {
      _isEmailActionInProgress = false;
    }
  }

  /// Resends account verification or signup confirmation email.
  Future<void> resendVerificationEmail({
    required String email,
    OtpType type = OtpType.signup,
  }) async {
    if (_isEmailActionInProgress) {
      throw const DuplicateRequestException(
        'A verification request is already being processed. Please wait a moment.',
      );
    }
    _isEmailActionInProgress = true;
    try {
      await _client.auth.resend(type: type, email: email.trim());
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(parseAuthErrorMessage(e));
    } finally {
      _isEmailActionInProgress = false;
    }
  }

  /// Registers a new user. The database trigger `handle_new_user` copies metadata into `profiles`.
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? enrollmentNo,
    String? branch,
    String? phone,
    String? companyName,
    String? emailRedirectTo,
  }) async {
    if (_isEmailActionInProgress) {
      throw const DuplicateRequestException(
        'A registration request is already being processed. Please wait a moment.',
      );
    }
    _isEmailActionInProgress = true;
    try {
      final rawData = {
        'full_name': fullName,
        'role': role,
        'enrollment_no': enrollmentNo,
        'branch': branch,
        'phone': phone,
        if (companyName != null && companyName.trim().isNotEmpty)
          'company_name': companyName.trim(),
      };

      final sanitized = sanitizeSignupMetadata(rawData);

      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: emailRedirectTo ?? SupabaseConfig.emailRedirectTo,
        data: sanitized,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(parseAuthErrorMessage(e));
    } finally {
      _isEmailActionInProgress = false;
    }
  }

  /// Verifies an email OTP code (e.g. 6-digit token) directly within the application.
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    OtpType type = OtpType.signup,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: type,
    );
  }

  /// Resends the confirmation link / code for an unverified account.
  Future<ResendResponse> resendSignupOtp(String email) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: SupabaseConfig.emailRedirectTo,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Fetches profile with self-healing fallback in case the database trigger failed.
  Future<AppUser> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No active authenticated user.');
    }
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      final meta = user.userMetadata ?? {};
      final fallback = {
        'id': user.id,
        'full_name': meta['full_name'] ?? '',
        'role': meta['role'] ?? 'student',
        'enrollment_no': meta['enrollment_no'],
        'branch': meta['branch'],
        'phone': meta['phone'],
        'designation': meta['designation'],
      };
      try {
        await _client.from('profiles').upsert(fallback);
      } catch (_) {
        // Fallback gracefully without throwing
      }
      return AppUser.fromMap(fallback, email: user.email ?? '');
    }
    return AppUser.fromMap(data, email: user.email ?? '');
  }

  Future<AppUser> updateProfile({
    required String fullName,
    String? enrollmentNo,
    String? branch,
    String? phone,
    String? designation,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No active authenticated user.');
    }
    final updatePayload = <String, dynamic>{
      'full_name': fullName,
      'enrollment_no': enrollmentNo,
      'branch': branch,
      'phone': phone,
    };
    if (designation != null) {
      updatePayload['designation'] = designation;
    }
    final data = await _client
        .from('profiles')
        .update(updatePayload)
        .eq('id', user.id)
        .select()
        .single();
    return AppUser.fromMap(data, email: user.email ?? '');
  }
}
