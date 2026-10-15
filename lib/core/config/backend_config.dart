import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  static String? _overrideUrl;

  static void setOverrideUrl(String? url) {
    _overrideUrl = url;
  }

  static String get baseUrl {
    if (_overrideUrl != null && _overrideUrl!.isNotEmpty) {
      return _overrideUrl!;
    }

    if (dotenv.isInitialized) {
      final envUrl = dotenv.env['BACKEND_URL'];
      if (envUrl != null && envUrl.isNotEmpty) {
        return envUrl;
      }
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    try {
      if (Platform.isAndroid) {
        // Standard Android emulator loopback alias to host localhost
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {
      // Fallback for non-standard environments
    }

    return 'http://localhost:3000';
  }

  static Duration get timeout => const Duration(seconds: 15);
}
