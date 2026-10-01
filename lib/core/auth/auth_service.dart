import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnauthenticatedException implements Exception {
  const UnauthenticatedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException(this.message);

  final String message;

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
    required VoidCallback onSessionChanged,
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
      } on AuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
        return;
      }
      onSessionChanged();
      return;
    }

    final signedIn = await showDialog<bool>(
      context: context,
      builder: (_) => _SignInDialog(client: client),
    );
    if (signedIn == true) onSessionChanged();
  }
}

class _SignInDialog extends StatefulWidget {
  final SupabaseClient client;

  const _SignInDialog({required this.client});

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
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
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _signIn(),
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
