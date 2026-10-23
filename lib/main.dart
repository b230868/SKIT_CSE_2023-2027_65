import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_gate.dart';
import 'core/config/supabase_config.dart';
import 'core/storage/cache_service.dart';
import 'core/theme.dart';
import 'features/geo_progress/services/geo_progress_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<Map>(GeoProgressQueue.boxName);
  await CacheService.init();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = SupabaseConfig.url.isNotEmpty
      ? SupabaseConfig.url
      : const String.fromEnvironment('SUPABASE_URL');
  final supabaseKey = SupabaseConfig.publishableKey.isNotEmpty
      ? SupabaseConfig.publishableKey
      : const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
          defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
        );

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError(
      'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in .env file '
      'or via --dart-define-from-file=.env.json before starting the app.',
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
