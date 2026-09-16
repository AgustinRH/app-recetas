import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'theme.dart';
import 'screens/feed_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/publish_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';

class DishTodayApp extends ConsumerWidget {
  const DishTodayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DishToday',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth.loading) return loc == '/splash' ? null : '/splash';
      if (!auth.isLoggedIn) return loc == '/login' ? null : '/login';
      final onboarding = auth.profile?.needsOnboarding ?? true;
      if (onboarding) return loc == '/onboarding' ? null : '/onboarding';
      if (loc == '/login' || loc == '/splash' || loc == '/onboarding') {
        return '/feed';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: '/recipe/:id',
        builder: (_, state) =>
            RecipeDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/publish', builder: (_, __) => const PublishScreen()),
      GoRoute(
        path: '/preferences',
        builder: (_, __) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/pantry', builder: (_, __) => const PantryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
