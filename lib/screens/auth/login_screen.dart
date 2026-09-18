import 'package:flutter/material.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});
@override
State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
final _email = TextEditingController();
final _password = TextEditingController();
final _auth = AuthService();
final _profiles = ProfileRepository();
bool _loading = false;
@override
void dispose() {
_email.dispose();
_password.dispose();
super.dispose();
}
Future<void> _login() async {
if (_email.text.trim().isEmpty || _password.text.isEmpty) {
_show('Enter email and password');
return;
}
setState(() => _loading = true);
try {
await _auth.signIn(
email: _email.text,
password: _password.text,
);
final profile = await _profiles.getCurrentProfile();
if (!mounted) return;
if (profile == null || profile['is_active'] != true) {
await _auth.signOut();
_show('This account is not active.');
return;
}
final role = profile['role'] as String;
if (role == 'industry_supervisor') {
Navigator.pushReplacementNamed(context, '/industry');
} else {
_show('Login succeeded. This role will be connected later.');
}
} catch (_) {
if (mounted) {
_show('Unable to sign in. Check your credentials and try again.');
}
} finally {
if (mounted) setState(() => _loading = false);
}
}
void _show(String message) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text('College ERP')),
body: Padding(
padding: const EdgeInsets.all(24),
child: Column(
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
),
const SizedBox(height: 16),
FilledButton(
onPressed: _loading ? null : _login,
child: Text(_loading ? 'Signing in...' : 'Sign in'),
),
],
),
),
);
}
}
