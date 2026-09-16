import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Demo login still works without google-services files.
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
