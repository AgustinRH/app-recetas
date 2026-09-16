import 'package:flutter/material.dart';
import '../theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🍽️', style: TextStyle(fontSize: 56)),
            SizedBox(height: 12),
            Text(
              'DishToday',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
