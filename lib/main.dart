import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_gate.dart';
import 'core/config/supabase_config.dart';
import 'core/theme.dart';
import 'features/geo_progress/services/geo_progress_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  await Hive.openBox<Map>(GeoProgressQueue.boxName);

  final supabaseUrl = SupabaseConfig.url;
  final supabaseKey = SupabaseConfig.publishableKey;
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError(
      'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (or the legacy '
      'SUPABASE_ANON_KEY) in the local .env file.',
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
