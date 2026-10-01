import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Native builds still work in demo until google-services files exist.
  }
  final container = ProviderContainer();
  await container.read(authProvider.notifier).restore();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DishTodayApp(),
    ),
  );
}
