import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_config.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_service.dart';
import '../utils/password_validator.dart';
import '../utils/phone_validator.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService? authService;

  const RegisterScreen({super.key, this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _roles = {
    'student': 'Student',
    'faculty': 'Faculty',
    'industry': 'Industry mentor',
  };
  static const _branches = ['CSE', 'IT', 'ECE', 'EE', 'ME', 'CE', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _enrollment = TextEditingController();
  final _company = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final AuthService _auth;

  String _role = 'student';
  String? _branch;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _isRateLimited = false;
  String? _rateLimitMessage;
  String? _databaseErrorMessage;
  String? _lastAttemptedEmail;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in [_name, _email, _phone, _enrollment, _company, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = seconds;
      _isRateLimited = true;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
          _isRateLimited = false;
          _rateLimitMessage = null;
        });
      } else {
        setState(() {
          _cooldownSeconds--;
        });
      }
    });
  }

  Future<void> _register() async {
    // Prevent multiple simultaneous registration submissions and respect cooldown
    if (_loading || _cooldownSeconds > 0) return;

    // Reset error banners
    setState(() {
      _databaseErrorMessage = null;
    });

    // Pre-validate all form fields before contacting Supabase
    if (!_formKey.currentState!.validate()) return;

    // Enforce strong password requirements before contacting Supabase
    if (!PasswordValidator.isStrong(_password.text)) {
      showSnack(
        context,
        'Password must satisfy all security requirements before proceeding.',
        error: true,
      );
      return;
    }

    if (_password.text != _confirm.text) {
      showSnack(context, 'Passwords do not match.', error: true);
      return;
    }

    final trimmedEmail = _email.text.trim().toLowerCase();

    // Prevent immediate duplicate signup attempt for the same email if already rate-limited
    if (_isRateLimited && _lastAttemptedEmail == trimmedEmail) {
      showSnack(
        context,
        'Email limit active for this address. Please wait $_cooldownSeconds seconds.',
        error: true,
      );
      return;
    }

    setState(() => _loading = true);
    _lastAttemptedEmail = trimmedEmail;

    try {
      final isStudent = _role == 'student';
      final isIndustry = _role == 'industry' || _role == 'industry_supervisor';
      final res = await _auth.register(
        email: trimmedEmail,
        password: _password.text,
        fullName: _name.text.trim(),
        role: _role,
        enrollmentNo: isStudent ? _enrollment.text.trim() : null,
        branch: isStudent ? _branch : null,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        companyName: isIndustry ? _company.text.trim() : null,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (res.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Please check your email inbox to verify your account before signing in.',
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        // Signed in already: AuthGate displays home screen, close register page
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      final formattedError = AuthErrorFormatter.format(e);

      final isRateLimit =
          e.statusCode == '429' ||
          e.code == 'over_email_send_rate_limit' ||
          e.code == 'over_request_rate_limit' ||
          e.message.toLowerCase().contains('rate limit') ||
          e.message.toLowerCase().contains('rate_limit');

      final isDbError =
          e.code == 'unexpected_failure' ||
          e.message.toLowerCase().contains('database error saving new user');

      if (isRateLimit) {
        _startCooldown(60);
        setState(() {
          _rateLimitMessage =
              'Email rate limit exceeded. Supabase email quota reached.\n'
              'Please wait $_cooldownSeconds seconds before retrying, or check if your confirmation email has arrived.';
        });
        showSnack(context, formattedError, error: true);
      } else if (isDbError) {
        setState(() {
          _databaseErrorMessage = formattedError;
        });
        showSnack(context, formattedError, error: true);
      } else {
        showSnack(context, formattedError, error: true);
      }
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          'Could not create the account. Try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final isStudent = _role == 'student';
    final isIndustry = _role == 'industry' || _role == 'industry_supervisor';
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                          labelText: 'I am a',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: _roles.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _role = v ?? 'student'),
                      ),
                    ),
                    AppTextField(
                      controller: _name,
                      label: 'Full name',
                      icon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Enter your full name'
                          : null,
                    ),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email address';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    AppTextField(
                      controller: _phone,
                      label: 'Mobile number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => PhoneValidator.validate(v),
                    ),
                    if (isStudent) ...[
                      AppTextField(
                        controller: _enrollment,
                        label: 'Enrollment number',
                        icon: Icons.numbers,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your enrollment number'
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DropdownButtonFormField<String>(
                          initialValue: _branch,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          items: _branches
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _branch = v),
                          validator: (v) =>
                              v == null ? 'Select your branch' : null,
                        ),
                      ),
                    ],
                    if (isIndustry) ...[
                      AppTextField(
                        controller: _company,
                        label: 'Company / Organization name',
                        icon: Icons.business_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your company or organization name'
                            : null,
                      ),
                    ],
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => setState(() {}),
                      validator: PasswordValidator.validate,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    _buildPasswordValidationFeedback(),
                    AppTextField(
                      controller: _confirm,
                      label: 'Confirm password',
                      icon: Icons.lock_outline,
                      obscure: _obscureConfirm,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          PasswordValidator.validateConfirm(v, _password.text),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscureConfirm
                            ? 'Show confirm password'
                            : 'Hide confirm password',
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    _buildConfirmValidationFeedback(),
                    if (_databaseErrorMessage != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Database Profile Error',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _databaseErrorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isRateLimited && _rateLimitMessage != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.hourglass_empty,
                              color: Colors.amber.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email Rate Limit Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _rateLimitMessage!,
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(
                                      'Already registered? Go to Login',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                        decoration: TextDecoration.underline,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    FilledButton(
                      onPressed: (_loading || _cooldownSeconds > 0)
                          ? null
                          : _register,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _cooldownSeconds > 0
                                  ? 'Please wait (${_cooldownSeconds}s)'
                                  : 'Create account',
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

  /// Field-level password feedback: displays compact inline badges while typing,
  /// and a concise single line when valid, avoiding large permanent panels.
  Widget _buildPasswordValidationFeedback() {
    final p = _password.text;

    if (p.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          'Requirements: 8+ chars, uppercase, lowercase, number, special char',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    final isStrong = PasswordValidator.isStrong(p);
    if (isStrong) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Row(
          children: const [
            Icon(Icons.check_circle, size: 14, color: Colors.green),
            SizedBox(width: 6),
            Text(
              'Strong password',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // While typing, show concise field-level requirement badges
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _buildCompactRequirementBadge(
            '8+ chars',
            PasswordValidator.hasMinLength(p),
          ),
          _buildCompactRequirementBadge(
            'Uppercase',
            PasswordValidator.hasUppercase(p),
          ),
          _buildCompactRequirementBadge(
            'Lowercase',
            PasswordValidator.hasLowercase(p),
          ),
          _buildCompactRequirementBadge(
            'Number',
            PasswordValidator.hasDigit(p),
          ),
          _buildCompactRequirementBadge(
            'Special char',
            PasswordValidator.hasSpecialChar(p),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRequirementBadge(String label, bool isMet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMet ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMet ? Colors.green.shade400 : Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check : Icons.circle,
            size: 10,
            color: isMet ? Colors.green.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
              color: isMet ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Field-level confirm password match indicator
  Widget _buildConfirmValidationFeedback() {
    final p = _password.text;
    final c = _confirm.text;
    if (c.isEmpty) return const SizedBox.shrink();

    final matches = (p == c && p.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(
            matches ? Icons.check_circle : Icons.error_outline,
            size: 14,
            color: matches ? Colors.green : Colors.red.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            matches ? 'Passwords match' : 'Passwords do not match',
            style: TextStyle(
              fontSize: 12,
              color: matches ? Colors.green : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
