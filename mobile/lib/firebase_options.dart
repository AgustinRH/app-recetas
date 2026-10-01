import 'package:firebase_core/firebase_core.dart';

/// Web app registered in Firebase project REDACTED_FIREBASE_PROJECT.
/// Android and iOS still need google-services.json / GoogleService-Info.plist.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REDACTED',
    authDomain: 'your-project.firebaseapp.com',
    projectId: 'REDACTED_FIREBASE_PROJECT',
    storageBucket: 'your-project.appspot.com',
    messagingSenderId: 'REDACTED_SENDER_ID',
    appId: 'REDACTED_APP_ID',
    measurementId: 'REDACTED',
  );
}
