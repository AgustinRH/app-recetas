import 'package:firebase_core/firebase_core.dart';

/// Firebase web options. Pass real values at build time with --dart-define.
/// Example:
/// flutter build web --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=...
class DefaultFirebaseOptions {
  static FirebaseOptions get web => FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
        authDomain: const String.fromEnvironment(
          'FIREBASE_AUTH_DOMAIN',
          defaultValue: 'your-project.firebaseapp.com',
        ),
        projectId: const String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'your-project',
        ),
        storageBucket: const String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
          defaultValue: 'your-project.appspot.com',
        ),
        messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        appId: const String.fromEnvironment('FIREBASE_APP_ID'),
        measurementId: const String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
      );
}
