import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnauthenticatedException implements Exception {
  final String message;

  const UnauthenticatedException(this.message);

  @override
  String toString() => message;
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
      throw const UnauthenticatedException('No active session.');
    }
  }

  static Future<void> showAuthDialog(
    BuildContext context, {
    required Future<void> Function() onSessionChanged,
  }) async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Account'),
          content: Text(client.auth.currentUser?.email ?? 'Signed in'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (shouldSignOut != true) return;
      try {
        await client.auth.signOut();
      } on AuthException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      }
      await onSessionChanged();
      return;
    }

    final signedIn = await showDialog<bool>(
      context: context,
      builder: (_) => _SignInDialog(client: client),
    );
    if (signedIn == true) await onSessionChanged();
  }
}

class _SignInDialog extends StatefulWidget {
  final SupabaseClient client;

  const _SignInDialog({required this.client});

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your email'
                  : null,
            ),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onFieldSubmitted: (_) => _signIn(),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter your password' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
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
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _signIn,
          child: Text(_loading ? 'Signing in...' : 'Sign in'),
        ),
      ],
    );
  }
}
