import 'package:flutter/material.dart';
<<<<<<< HEAD
=======
import 'package:flutter_dotenv/flutter_dotenv.dart';
>>>>>>> f5707ce ( Hive offline cache)
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_gate.dart';
import 'core/theme.dart';
import 'features/geo_progress/services/geo_progress_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<Map>(GeoProgressQueue.boxName);
<<<<<<< HEAD
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
=======
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseKey =
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseKey == null ||
      supabaseKey.isEmpty) {
>>>>>>> f5707ce ( Hive offline cache)
    throw StateError(
      'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (or the legacy '
      'SUPABASE_ANON_KEY) with '
      '--dart-define-from-file=.env.json before starting the app.',
    );
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const PrashikshanApp());
}

class PrashikshanApp extends StatelessWidget {
  final Widget home;

  const PrashikshanApp({super.key, this.home = const AuthGate()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prashikshan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    );
  }
}
