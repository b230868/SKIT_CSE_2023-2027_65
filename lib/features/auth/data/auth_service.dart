import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

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
        await _client.from('profiles').select().eq('id', user.id).single();
    return AppUser.fromMap(data, email: user.email ?? '');
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
