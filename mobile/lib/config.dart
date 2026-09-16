import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:3000';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://127.0.0.1:3000';
  }

  static const useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: true,
  );
}
