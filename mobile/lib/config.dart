
class AppConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // API pública en Hetzner (puerto 80). Override: --dart-define=API_BASE_URL=...
    return 'http://REDACTED';
  }

  static const useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: true,
  );
}
