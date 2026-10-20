import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/faculty_tp/presentation/screens/faculty_dashboard_screen.dart';
import '../../features/faculty_tp/presentation/screens/student_dashboard_screen.dart';
import '../../features/faculty_tp/presentation/screens/tp_dashboard_screen.dart';

enum AppRole { student, facultyMentor, tpOfficer, industrySupervisor, admin }

extension AppRoleExtension on AppRole {
  String get value {
    switch (this) {
      case AppRole.student:
        return 'student';
      case AppRole.facultyMentor:
        return 'faculty_mentor';
      case AppRole.tpOfficer:
        return 'tp_officer';
      case AppRole.industrySupervisor:
        return 'industry_supervisor';
      case AppRole.admin:
        return 'admin';
    }
  }

  static AppRole fromString(String? role) {
    switch (role) {
      case 'faculty_mentor':
        return AppRole.facultyMentor;
      case 'tp_officer':
        return AppRole.tpOfficer;
      case 'industry_supervisor':
        return AppRole.industrySupervisor;
      case 'admin':
        return AppRole.admin;
      case 'student':
      default:
        return AppRole.student;
    }
  }
}

class UserProfile {
  final String id;
  final String? fullName;
  final String? email;
  final AppRole role;
  final String? department;
  final bool isActive;

  const UserProfile({
    required this.id,
    this.fullName,
    this.email,
    required this.role,
    this.department,
    this.isActive = true,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      role: AppRoleExtension.fromString(map['role'] as String?),
      department: map['department'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class AuthService {
  final SupabaseClient? _client;

  AuthService({SupabaseClient? client}) : _client = client ?? _resolveClient();

  static SupabaseClient? _resolveClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get client {
    final explicitClient = _client;
    if (explicitClient != null) return explicitClient;
    return Supabase.instance.client;
  }

  User? get currentUser => _client?.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String? get currentUserId => currentUser?.id;

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    final activeClient = _client;
    if (user == null || activeClient == null) return null;

    try {
      final response = await activeClient
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromMap(response);
    } catch (_) {
      return null;
    }
  }

  // In-flight concurrency lock to prevent accidental double-clicks and concurrent duplicate requests
  static bool _isEmailActionInProgress = false;

  /// True if an email-triggering auth request is actively in-flight.
  static bool get isEmailActionInProgress => _isEmailActionInProgress;

  /// Translates raw auth and Supabase exceptions into human-friendly, production-level guidance.
  /// Handles `over_email_send_rate_limit` (HTTP 429) specifically.
  static String parseAuthErrorMessage(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('over_email_send_rate_limit') ||
        str.contains('email rate limit') ||
        str.contains('429') ||
        str.contains('too many requests')) {
      return 'Email delivery rate limit reached by Supabase Auth (built-in 2-4 emails/hr quota exceeded). Please wait before retrying, or configure a custom SMTP provider or Send Email Hook in Supabase Dashboard.';
    }
    if (str.contains('invalid login credentials') ||
        str.contains('invalid_grant')) {
      return 'Invalid email or password. Please verify your credentials and try again.';
    }
    if (str.contains('email not confirmed')) {
      return 'Email address is not yet confirmed. Please verify your email or contact an administrator.';
    }
    if (str.contains('user already registered') ||
        str.contains('already been registered')) {
      return 'An account with this email address already exists. Please sign in or use password recovery.';
    }
    if (str.contains('access denied') || str.contains('only administrators')) {
      return 'Access denied: Only administrators can assign elevated user roles.';
    }
    if (str.contains('target user profile not found')) {
      return 'Target user profile not found.';
    }
    if (str.contains('network') ||
        str.contains('socketexception') ||
        str.contains('failed host lookup')) {
      return 'Network connection error. Please verify your internet connection.';
    }
    return 'Authentication error: $error';
  }

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends a password reset email using Supabase Auth with in-flight duplicate-click protection.
  /// Immediate retry is allowed upon completion or failure (no arbitrary application cooldown).
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
      await client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo,
      );
    } catch (e) {
      throw AuthException(parseAuthErrorMessage(e));
    } finally {
      _isEmailActionInProgress = false;
    }
  }

  /// Sanitizes client-supplied signup metadata by stripping any attempted role elevation parameters.
  /// Public self-signups are strictly prevented from supplying 'role' or 'app_role'.
  static Map<String, dynamic>? sanitizeSignupMetadata(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.remove('role');
    sanitized.remove('app_role');
    sanitized.remove('roles');
    sanitized.remove('is_admin');
    sanitized.remove('isAdmin');
    return sanitized;
  }

  /// Secure administrative RPC call to assign an elevated role to a user.
  /// Requires caller to have authenticated session with 'admin' role.
  /// Denied for unauthenticated callers, student callers, and other non-admin roles.
  Future<void> adminAssignUserRole({
    required String targetUserId,
    required AppRole newRole,
  }) async {
    final trimmedId = targetUserId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('targetUserId cannot be empty.');
    }

    try {
      await client.rpc(
        'admin_assign_user_role',
        params: {'target_user_id': trimmedId, 'new_role': newRole.name},
      );
    } catch (e) {
      throw AuthException(parseAuthErrorMessage(e));
    }
  }

  /// Registers a new user with Supabase Auth with in-flight duplicate-click protection.
  /// Controls immediately re-enable on failure or completion.
  /// Security Defense: Client-supplied role metadata is strictly sanitized and stripped.
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    if (_isEmailActionInProgress) {
      throw const DuplicateRequestException(
        'A registration request is already being processed. Please wait a moment.',
      );
    }
    _isEmailActionInProgress = true;
    try {
      // Defense-in-depth: Never transmit client-supplied role metadata during public self-signup
      final sanitizedData = sanitizeSignupMetadata(data);

      return await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: sanitizedData,
      );
    } catch (e) {
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
      await client.auth.resend(type: type, email: email.trim());
    } catch (e) {
      throw AuthException(parseAuthErrorMessage(e));
    } finally {
      _isEmailActionInProgress = false;
    }
  }

  /// Updates authenticated user's password (e.g. after following recovery link).
  Future<UserResponse> updateUserPassword({required String newPassword}) async {
    return await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  static bool get hasActiveSession {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        return false;
      }
      return !session.isExpired;
    } catch (_) {
      return false;
    }
  }

  static User? get currentAuthUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Returns the initialized client only when a usable user JWT is present.
  /// Does not query protected tables; callers must still use this client.
  static Future<SupabaseClient> requireAuthenticatedClient({
    SupabaseClient? client,
  }) async {
    SupabaseClient? resolved = client;
    if (resolved == null) {
      try {
        resolved = Supabase.instance.client;
      } catch (_) {
        resolved = null;
      }
    }

    if (resolved == null) {
      throw const UnauthenticatedException();
    }

    var session = resolved.auth.currentSession;
    if (session == null || session.isExpired || session.accessToken.isEmpty) {
      try {
        final refreshed = await resolved.auth.refreshSession();
        session = refreshed.session ?? resolved.auth.currentSession;
      } catch (_) {
        session = resolved.auth.currentSession;
      }
    }

    if (session == null || session.accessToken.isEmpty) {
      throw const UnauthenticatedException();
    }

    return resolved;
  }

  static void showAuthDialog(
    BuildContext context, {
    Future<void> Function()? onSessionChanged,
    bool routeAfterLogin = true,
  }) {
    final user = currentAuthUser;
    if (user != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Account Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Signed in as: ${user.email ?? "Unknown"}'),
              const SizedBox(height: 8),
              Text('User ID: ${user.id}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client.auth.signOut();
                } catch (_) {}
                await onSessionChanged?.call();
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
    } else {
      final nameController = TextEditingController();
      final emailController = TextEditingController();
      final passwordController = TextEditingController();
      final confirmPasswordController = TextEditingController();
      int mode = 0; // 0 = Sign In, 1 = Sign Up, 2 = Forgot Password
      bool isSubmitting = false;
      bool obscurePassword = true;
      bool obscureConfirmPassword = true;
      String? authError;
      String? successMessage;

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final title = mode == 1
                ? 'Create Account'
                : mode == 2
                ? 'Reset Password'
                : 'Sign In';

            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (authError != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(dialogCtx).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          authError!,
                          style: TextStyle(
                            color: Theme.of(dialogCtx)
                                .colorScheme
                                .onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          successMessage!,
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (mode == 1) ...[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'e.g. John Doe',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'e.g. user@college.edu',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isSubmitting,
                    ),
                    if (mode != 2) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: obscurePassword,
                        enabled: !isSubmitting,
                      ),
                      if (mode == 1) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: obscureConfirmPassword,
                          enabled: !isSubmitting,
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'Enter your registered email address to receive password recovery instructions.',
                        style: TextStyle(
                          color: Theme.of(dialogCtx)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (mode == 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setDialogState(() {
                                      mode = 2;
                                      authError = null;
                                      successMessage = null;
                                    });
                                  },
                            child: const Text('Forgot Password?'),
                          ),
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setDialogState(() {
                                      mode = 1;
                                      authError = null;
                                      successMessage = null;
                                    });
                                  },
                            child: const Text('Create Account'),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  mode = 0;
                                  authError = null;
                                  successMessage = null;
                                });
                              },
                        child: const Text('Already have an account? Sign In'),
                      ),
                    ],
                    if (isSubmitting) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final password = passwordController.text;

                          // Email validation for all modes
                          if (email.isEmpty) {
                            setDialogState(() {
                              authError = 'Please enter an email address.';
                            });
                            return;
                          }

                          if (!emailRegex.hasMatch(email)) {
                            setDialogState(() {
                              authError =
                                  'Please enter a valid email address format.';
                            });
                            return;
                          }

                          // Mode-specific input validations
                          if (mode == 0) {
                            // Sign In
                            if (password.isEmpty) {
                              setDialogState(() {
                                authError = 'Please enter your password.';
                              });
                              return;
                            }
                          } else if (mode == 1) {
                            // Sign Up
                            final fullName = nameController.text.trim();
                            if (fullName.isEmpty) {
                              setDialogState(() {
                                authError = 'Please enter your full name.';
                              });
                              return;
                            }
                            if (fullName.length < 2) {
                              setDialogState(() {
                                authError =
                                    'Full name must be at least 2 characters.';
                              });
                              return;
                            }
                            if (password.isEmpty) {
                              setDialogState(() {
                                authError = 'Please enter a password.';
                              });
                              return;
                            }
                            if (password.length < 6) {
                              setDialogState(() {
                                authError = 'Password must be at least 6 characters long.';
                              });
                              return;
                            }
                            final confirmPassword =
                                confirmPasswordController.text;
                            if (password != confirmPassword) {
                              setDialogState(() {
                                authError =
                                    'Passwords do not match. Please verify.';
                              });
                              return;
                            }
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            authError = null;
                            successMessage = null;
                          });

                          try {
                            if (mode == 0) {
                              // Sign In
                              await Supabase.instance.client.auth
                                  .signInWithPassword(
                                    email: email,
                                    password: password,
                                  );

                              final profile = await AuthService()
                                  .getCurrentUserProfile();

                              if (!dialogCtx.mounted) return;
                              Navigator.pop(dialogCtx);
                              await onSessionChanged?.call();

                              if (routeAfterLogin &&
                                  context.mounted &&
                                  profile != null) {
                                AuthService.navigateForRole(
                                  context,
                                  profile.role,
                                );
                              }
                            } else if (mode == 1) {
                              // Sign Up
                              final fullName = nameController.text.trim();
                              final res = await AuthService()
                                  .signUpWithEmailPassword(
                                    email: email,
                                    password: password,
                                    data: fullName.isNotEmpty
                                        ? {'full_name': fullName}
                                        : null,
                                  );

                              if (!dialogCtx.mounted) return;
                              setDialogState(() {
                                isSubmitting = false;
                                if (res.session == null) {
                                  successMessage = 'Account registration submitted! Please check your email inbox to verify your account before signing in.';
                                } else {
                                  successMessage = 'Account created successfully! You are now signed in.';
                                }
                              });

                              if (res.session != null) {
                                await onSessionChanged?.call();
                                if (routeAfterLogin && context.mounted) {
                                  AuthService.navigateForRole(
                                    context,
                                    AppRole.student,
                                  );
                                }
                              }
                            } else if (mode == 2) {
                              // Forgot Password
                              await AuthService().sendPasswordResetEmail(
                                email: email,
                              );
                              if (!dialogCtx.mounted) return;
                              setDialogState(() {
                                isSubmitting = false;
                                successMessage = 'Password reset instructions sent! Please check your email inbox.';
                              });
                            }
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() {
                              isSubmitting = false;
                              authError = AuthService.parseAuthErrorMessage(e);
                            });
                          }
                        },
                  child: Text(
                    mode == 1
                        ? 'Create Account'
                        : mode == 2
                        ? 'Send Reset Link'
                        : 'Sign In',
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  /// Navigates the user to their designated dashboard according to their role.
  static void navigateForRole(BuildContext context, AppRole role) {
    Widget targetScreen;
    switch (role) {
      case AppRole.tpOfficer:
        targetScreen = const TpDashboardScreen();
        break;
      case AppRole.student:
        targetScreen = const StudentDashboardScreen();
        break;
      case AppRole.facultyMentor:
      case AppRole.admin:
      case AppRole.industrySupervisor:
        targetScreen = const FacultyDashboardScreen();
        break;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => targetScreen),
      (route) => false,
    );
  }
}

class DuplicateRequestException implements Exception {
  final String message;
  const DuplicateRequestException([
    this.message = 'A request is currently in progress. Please wait a moment.',
  ]);

  @override
  String toString() => message;
}

class RateLimitException implements Exception {
  final String message;
  const RateLimitException([
    this.message = 'Email rate limit exceeded. Please wait before retrying.',
  ]);

  @override
  String toString() => message;
}

class UnauthenticatedException implements Exception {
  final String message;
  const UnauthenticatedException([
    this.message = 'Please sign in to access approval data.',
  ]);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([
    this.message =
        'Your account does not have permission to access approval data.',
  ]);

  @override
  String toString() => message;
}
