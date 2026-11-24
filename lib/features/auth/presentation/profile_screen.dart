import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../models/app_user.dart';
import '../utils/phone_validator.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;
  final ValueChanged<AppUser>? onUpdated;

  const ProfileScreen({super.key, required this.user, this.onUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthService get _auth => AuthService();
  late final TextEditingController _name;
  late final TextEditingController _enrollment;
  late final TextEditingController _branch;
  late final TextEditingController _phone;
  late final TextEditingController _designation;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u.fullName);
    _enrollment = TextEditingController(text: u.enrollmentNo ?? '');
    _branch = TextEditingController(text: u.branch ?? '');
    _phone = TextEditingController(text: u.phone ?? '');
    _designation = TextEditingController(text: u.designation ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _enrollment, _branch, _phone, _designation]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await _auth.updateProfile(
        fullName: _name.text.trim(),
        enrollmentNo: _nullIfEmpty(_enrollment.text),
        branch: _nullIfEmpty(_branch.text),
        phone: _nullIfEmpty(_phone.text),
        designation: _nullIfEmpty(_designation.text),
      );
      widget.onUpdated?.call(updated);
      if (mounted) showSnack(context, 'Profile saved');
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not save your profile', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool busy = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a new secure password (at least 6 characters):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final p1 = newPassCtrl.text;
                      final p2 = confirmPassCtrl.text;
                      if (p1.length < 6) {
                        setDialogState(() {
                          errorText = 'Password must be at least 6 characters.';
                        });
                        return;
                      }
                      if (p1 != p2) {
                        setDialogState(() {
                          errorText = 'Passwords do not match.';
                        });
                        return;
                      }

                      setDialogState(() {
                        busy = true;
                        errorText = null;
                      });

                      try {
                        if (!widget.user.id.startsWith('demo-')) {
                          await _auth.updatePassword(p1);
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          showSnack(context, 'Password updated successfully!');
                        }
                      } catch (err) {
                        setDialogState(() {
                          errorText = AuthService.parseAuthErrorMessage(err);
                          busy = false;
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _auth.signOut(); // AuthGate returns to Login
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final isStudent = u.role == 'student';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.ink,
                          child: Text(
                            u.initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.fullName.isEmpty ? 'Your name' : u.fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                u.email,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                u.roleLabel,
                                style: const TextStyle(
                                  color: AppTheme.saffron,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (u.designation != null &&
                                  u.designation!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  u.designation!,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _name,
                      label: 'Full name',
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Enter your full name'
                          : null,
                    ),
                    if (u.role == 'industry' ||
                        u.role == 'industry_supervisor') ...[
                      AppTextField(
                        controller: _designation,
                        label: 'Professional designation',
                        icon: Icons.badge_outlined,
                      ),
                    ],
                    if (isStudent) ...[
                      AppTextField(
                        controller: _enrollment,
                        label: 'Enrollment number',
                        icon: Icons.numbers,
                      ),
                      AppTextField(
                        controller: _branch,
                        label: 'Branch',
                        icon: Icons.school_outlined,
                      ),
                    ],
                    AppTextField(
                      controller: _phone,
                      label: 'Mobile number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => PhoneValidator.validate(v),
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save changes'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _changePassword,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Change password'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        'Sign out',
                        style: TextStyle(color: Colors.redAccent),
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
