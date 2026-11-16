import 'package:firebase_core/firebase_core.dart';

/// Placeholder Firebase web options so the project analyzes/builds without secrets.
///
/// For a real project, replace this file by running:
///   cd mobile && flutterfire configure
/// or copy [firebase_options.example.dart] and fill in your Firebase console values.
///
/// The web API key is public by design; restrict it by domain in Google Cloud.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    authDomain: 'YOUR_PROJECT.firebaseapp.com',
    projectId: 'YOUR_PROJECT',
    storageBucket: 'YOUR_PROJECT.appspot.com',
    messagingSenderId: 'YOUR_SENDER_ID',
    appId: 'YOUR_APP_ID',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );
}
