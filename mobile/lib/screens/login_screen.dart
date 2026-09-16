import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';
import '../providers.dart';
import '../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController(text: 'demo@dishtoday.app');
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            const Text('🍽️', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
            const Text(
              'DishToday',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Qué puedes cocinar con lo que tienes?',
              textAlign: TextAlign.center,
              style: TextStyle(color: ink.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (!AppConfig.useDevAuth) ...[
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: auth.loading
                  ? null
                  : () {
                      if (AppConfig.useDevAuth) {
                        ref.read(authProvider.notifier).loginDemo(email.text.trim());
                      } else {
                        ref.read(authProvider.notifier).loginEmail(
                              email.text.trim(),
                              password.text,
                            );
                      }
                    },
              child: Text(AppConfig.useDevAuth ? 'Entrar en demo' : 'Entrar / registrarse'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: auth.loading
                  ? null
                  : () => ref.read(authProvider.notifier).loginGoogle(),
              icon: const Icon(Icons.g_mobiledata),
              label: const Text('Continuar con Google'),
            ),
            if (!kIsWeb && Platform.isIOS) ...[
              const SizedBox(height: 8),
              SignInWithAppleButton(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Apple Sign-In requiere Firebase y un Apple Developer account.',
                      ),
                    ),
                  );
                },
              ),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: 16),
              Text(auth.error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            Text(
              AppConfig.useDevAuth
                  ? 'Demo: demo@dishtoday.app (sin Firebase)'
                  : 'Email, Google o Apple',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
