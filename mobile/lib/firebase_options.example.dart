// ignore_for_file: lines_longer_than_80_chars
//
// Example Firebase options for DishToday.
//
// Prefer generating a real file with FlutterFire:
//   cd mobile
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Or copy this file:
//   cp lib/firebase_options.example.dart lib/firebase_options.dart
// and replace the placeholder values with your Firebase web app config.
// Do not commit production secrets beyond the usual public web API key
// (restrict that key by HTTP referrer / domain in Google Cloud).

import 'package:firebase_core/firebase_core.dart';

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
