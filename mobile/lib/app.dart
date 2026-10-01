import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'theme.dart';
import 'screens/admin_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/publish_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/shopping_screen.dart';
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
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
      final legal = loc == '/privacidad' || loc == '/condiciones';
      final shared = loc.startsWith('/recipe/');
      if (auth.loading) return loc == '/splash' || legal || shared ? null : '/splash';
      if (!auth.isLoggedIn) return loc == '/login' || legal || shared ? null : '/login';
      final onboarding = (auth.profile?.needsOnboarding ?? true) ||
          ref.read(onboardingPendingProvider);
      if (onboarding && !legal) return loc == '/onboarding' ? null : '/onboarding';
      if (loc == '/admin' && auth.profile?.isAdmin != true) return '/feed';
      if (loc == '/login' || loc == '/splash' || loc == '/onboarding') {
        final back = ref.read(returnToProvider);
        if (back != null) {
          Future.microtask(() => ref.read(returnToProvider.notifier).state = null);
          return back;
        }
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
      GoRoute(path: '/shopping', builder: (_, __) => const ShoppingScreen()),
      GoRoute(path: '/planner', builder: (_, __) => const PlannerScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(
        path: '/privacidad',
        builder: (_, __) => const LegalScreen(kind: LegalKind.privacy),
      ),
      GoRoute(
        path: '/condiciones',
        builder: (_, __) => const LegalScreen(kind: LegalKind.terms),
      ),
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
