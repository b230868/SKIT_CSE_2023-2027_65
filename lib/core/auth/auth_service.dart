import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnauthenticatedException implements Exception {
<<<<<<< HEAD
  const UnauthenticatedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException(this.message);

  final String message;

=======
  const UnauthenticatedException();

  @override
  String toString() => 'Authentication is required.';
}

class UnauthorizedException implements Exception {
  final String message;

  const UnauthorizedException(this.message);

>>>>>>> yash
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
<<<<<<< HEAD
      throw const UnauthenticatedException('No active session.');
=======
      throw const UnauthenticatedException();
>>>>>>> yash
    }
  }

  static Future<void> showAuthDialog(
    BuildContext context, {
<<<<<<< HEAD
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
=======
    Future<void> Function()? onSessionChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _SignInDialog(onSessionChanged: onSessionChanged),
    );
>>>>>>> yash
  }
}

class _SignInDialog extends StatefulWidget {
<<<<<<< HEAD
  final SupabaseClient client;

  const _SignInDialog({required this.client});
=======
  final Future<void> Function()? onSessionChanged;

  const _SignInDialog({this.onSessionChanged});
>>>>>>> yash

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
<<<<<<< HEAD
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
=======
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
>>>>>>> yash
    super.dispose();
  }

  Future<void> _signIn() async {
<<<<<<< HEAD
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
=======
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
>>>>>>> yash
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in'),
<<<<<<< HEAD
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
=======
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
>>>>>>> yash
        ),
      ],
    );
  }
}
