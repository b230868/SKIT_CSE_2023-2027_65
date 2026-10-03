import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnauthenticatedException implements Exception {
  const UnauthenticatedException();

  @override
  String toString() => 'Authentication is required.';
}

class UnauthorizedException implements Exception {
  final String message;

  const UnauthorizedException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static bool get hasActiveSession {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } on AssertionError {
      return false;
    }
  }

  static Future<void> requireAuthenticatedClient({
    required SupabaseClient client,
  }) async {
    if (client.auth.currentSession == null) {
      throw const UnauthenticatedException();
    }
  }

  static Future<void> showAuthDialog(
    BuildContext context, {
    Future<void> Function()? onSessionChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _SignInDialog(onSessionChanged: onSessionChanged),
    );
  }
}

class _SignInDialog extends StatefulWidget {
  final Future<void> Function()? onSessionChanged;

  const _SignInDialog({this.onSessionChanged});

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSigningIn = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSessionChanged?.call();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your email'
                  : null,
            ),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter your password' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSigningIn ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSigningIn ? null : _signIn,
          child: _isSigningIn
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
      ],
    );
  }
}
