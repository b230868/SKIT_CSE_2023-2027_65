import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

class AuthService {
  static const _configuredAuthRedirectUrl =
      String.fromEnvironment('SUPABASE_AUTH_REDIRECT_URL');

  final SupabaseClient _client = Supabase.instance.client;

  String? get _emailRedirectTo {
    if (_configuredAuthRedirectUrl.isNotEmpty) {
      return _configuredAuthRedirectUrl;
    }
    return kIsWeb ? Uri.base.origin : null;
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// The database trigger `handle_new_user` copies these values into `profiles`.
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? enrollmentNo,
    String? branch,
    String? phone,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _emailRedirectTo,
      data: {
        'full_name': fullName,
        'role': role,
        'enrollment_no': enrollmentNo,
        'branch': branch,
        'phone': phone,
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<AppUser> fetchProfile() async {
    final user = _client.auth.currentUser!;
    final data =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();

    if (data != null) {
      return AppUser.fromMap(data, email: user.email ?? '');
    }

    // Fallback: If DB trigger hasn't created the profile row yet, read from profile or user metadata
    final metadata = user.userMetadata ?? {};
    final fullName = (metadata['full_name'] as String?)?.trim();
    // Default strictly to 'student' to prevent privilege escalation
    final role = (metadata['role'] as String?)?.trim() ?? 'student';
    final enrollmentNo = metadata['enrollment_no'] as String?;
    final branch = metadata['branch'] as String?;
    final phone = metadata['phone'] as String?;

    try {
      final inserted = await _client.from('profiles').insert({
        'id': user.id,
        'full_name': fullName ?? (user.email?.split('@').first ?? 'Student'),
        'role': role,
        'enrollment_no': enrollmentNo,
        'branch': branch,
        'phone': phone,
      }).select().single();
      return AppUser.fromMap(inserted, email: user.email ?? '');
    } catch (_) {
      // If insert fails due to existing row or permissions, return user from metadata
      return AppUser(
        id: user.id,
        fullName: fullName ?? (user.email?.split('@').first ?? 'Student'),
        email: user.email ?? '',
        role: role,
        enrollmentNo: enrollmentNo,
        branch: branch,
        phone: phone,
      );
    }
  }

  Future<AppUser> updateProfile({
    required String fullName,
    String? enrollmentNo,
    String? branch,
    String? phone,
  }) async {
    final user = _client.auth.currentUser!;
    final data = await _client
        .from('profiles')
        .update({
          'full_name': fullName,
          'enrollment_no': enrollmentNo,
          'branch': branch,
          'phone': phone,
        })
        .eq('id', user.id)
        .select()
        .single();
    return AppUser.fromMap(data, email: user.email ?? '');
  }
}
