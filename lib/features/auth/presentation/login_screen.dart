import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../faculty_tp/presentation/screens/faculty_dashboard_screen.dart';
import '../../faculty_tp/presentation/screens/tp_dashboard_screen.dart';
import '../../industry/presentation/screens/industry_shell.dart';
import '../../student/student_shell.dart';
import '../data/auth_service.dart';
import '../models/app_user.dart';
import '../utils/email_validator.dart';
import 'register_screen.dart';

const demoStudent = AppUser(
  id: 'demo-student-id',
  fullName: 'Vidhi Sharma',
  email: 'vidhi.sharma@skit.ac.in',
  role: 'student',
  enrollmentNo: 'SKIT/2023/CSE/065',
  branch: 'CSE',
  phone: '+91 98765 43210',
  designation: 'Student',
);

const demoFaculty = AppUser(
  id: 'demo-faculty-id',
  fullName: 'Dr. Ramesh Kumar',
  email: 'ramesh.faculty@skit.ac.in',
  role: 'faculty_mentor',
  branch: 'CSE',
  phone: '+91 98765 11111',
  designation: 'Associate Professor',
);

const demoTp = AppUser(
  id: 'demo-tp-id',
  fullName: 'T&P Officer',
  email: 'tp.officer@skit.ac.in',
  role: 'tp_officer',
  branch: 'T&P Cell',
  phone: '+91 98765 22222',
  designation: 'Training & Placement Officer',
);

const demoIndustry = AppUser(
  id: 'demo-industry-id',
  fullName: 'Vikram Mehta',
  email: 'vikram@infosys.com',
  role: 'industry_supervisor',
  branch: 'IT & Software',
  phone: '+91 98765 33333',
  designation: 'Senior Project Manager',
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      final res = await _auth.signIn(email, _password.text);
      final user = res.user ?? Supabase.instance.client.auth.currentUser;

      // Only check unverified email if Supabase denied issuing a session:
      // If a valid session exists or user is faculty/staff, allow login without blocking
      final meta = user?.userMetadata ?? {};
      final role = (meta['role'] ?? '').toString().toLowerCase().trim();
      final isStaffOrFaculty = role == 'faculty' ||
          role == 'faculty_mentor' ||
          role == 'tnp' ||
          role == 'tp_officer' ||
          role == 'admin';

      if (res.session == null && !isStaffOrFaculty && user != null && user.emailConfirmedAt == null) {
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Email not verified. Please verify via your inbox before signing in.',
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Resend',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await _auth.resendVerificationEmail(email: email);
                    if (mounted) {
                      showSnack(context, 'Verification email sent to $email');
                    }
                  } catch (e) {
                    if (mounted) {
                      showSnack(
                        context,
                        AuthService.parseAuthErrorMessage(e),
                        error: true,
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
        return;
      }
      // AuthGate reacts to the verified session and navigates automatically.
    } on AuthException catch (e) {
      if (mounted) {
        showSnack(
          context,
          AuthService.parseAuthErrorMessage(e.message),
          error: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, AuthService.parseAuthErrorMessage(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _email.text.trim(),
    );
    bool resetting = false;
    String? resetError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your registered email address to receive password recovery instructions.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                if (resetError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    resetError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: resetting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: resetting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setDialogState(() {
                            resetError = 'Please enter a valid email address.';
                          });
                          return;
                        }

                        setDialogState(() {
                          resetting = true;
                          resetError = null;
                        });

                        try {
                          await _auth.sendPasswordResetEmail(email: email);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (mounted) {
                            showSnack(
                              context,
                              'Password reset instructions sent to $email.',
                            );
                          }
                        } catch (err) {
                          setDialogState(() {
                            resetError = AuthService.parseAuthErrorMessage(err);
                            resetting = false;
                          });
                        }
                      },
                child: resetting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          );
        },
      ),
    );
    resetEmailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Prashikshan',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Internships and ITR, tracked in one place.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 36),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: EmailValidator.validate,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password'
                            : null,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _showForgotPasswordDialog,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                      child: const Text('New here? Create an account'),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR EXPLORE DEMO ROLES',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: const Color(0xFFF8F9FA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Instant Feature Walkthrough:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.school, color: AppTheme.ink),
                              label: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Student Portal (Vidhi - CSE)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Dashboard, Internships, Reports, Analytics & Alerts',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const StudentShell(user: demoStudent),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.co_present, color: Colors.teal),
                              label: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Faculty Mentor Portal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Student Monitoring, Approvals & Faculty Reports',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FacultyDashboardScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.business_center, color: Colors.deepOrange),
                              label: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Training & Placement Officer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'T&P Dashboard, Assignments & Final Approvals',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TpDashboardScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(Icons.factory, color: Colors.indigo),
                              label: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Industry Supervisor Portal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  Text(
                                    'Student Evaluations & Document Verification',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const IndustryShell(user: demoIndustry),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
