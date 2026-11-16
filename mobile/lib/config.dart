
class AppConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Local default. Override: --dart-define=API_BASE_URL=https://api.dishtoday.eu
    return 'http://localhost:3010';
  }

  static const useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: true,
  );
}
