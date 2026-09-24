import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../models/app_user.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;
  final ValueChanged<AppUser>? onUpdated;

  const ProfileScreen({super.key, required this.user, this.onUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  late final TextEditingController _name;
  late final TextEditingController _enrollment;
  late final TextEditingController _branch;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u.fullName);
    _enrollment = TextEditingController(text: u.enrollmentNo ?? '');
    _branch = TextEditingController(text: u.branch ?? '');
    _phone = TextEditingController(text: u.phone ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _enrollment, _branch, _phone]) {
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
      );
      widget.onUpdated?.call(updated);
      if (mounted) showSnack(context, 'Profile saved');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save your profile', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await _auth.signOut(); // AuthGate returns to Login
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
                          child: Text(u.initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.fullName.isEmpty ? 'Your name' : u.fullName,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(u.email,
                                  style: TextStyle(color: Colors.grey.shade700)),
                              const SizedBox(height: 2),
                              Text(u.roleLabel,
                                  style: const TextStyle(
                                      color: AppTheme.saffron,
                                      fontWeight: FontWeight.w700)),
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return RegExp(r'^\d{10}$').hasMatch(v.trim())
                            ? null
                            : 'Enter a 10-digit number';
                      },
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Save changes'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
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
