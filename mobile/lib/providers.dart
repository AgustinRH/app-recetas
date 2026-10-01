import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';
import 'config.dart';
import 'models.dart';

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthState {
  const AuthState({this.profile, this.loading = true, this.error});

  final UserProfile? profile;
  final bool loading;
  final String? error;

  bool get isLoggedIn => profile != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api) : super(const AuthState());

  final ApiClient _api;

  Future<void> restore() async {
    state = const AuthState(loading: true);
    try {
      if (AppConfig.useDevAuth) {
        state = const AuthState(loading: false);
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = const AuthState(loading: false);
        return;
      }
      _api.setToken(await user.getIdToken());
      final profile = await _api.syncAuth(displayName: user.displayName);
      state = AuthState(profile: profile, loading: false);
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
    }
  }

  Future<void> loginDemo(String email) async {
    state = state.copy(loading: true, error: null);
    try {
      _api.setToken('dev:$email');
      final profile = await _api.syncAuth(displayName: email.split('@').first);
      state = AuthState(profile: profile, loading: false);
    } catch (e) {
      state = AuthState(loading: false, error: 'No se pudo conectar con la API');
    }
  }

  Future<void> loginGoogle() async {
    state = state.copy(loading: true, error: null);
    try {
      final User user;
      if (kIsWeb) {
        final cred = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
        user = cred.user!;
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          state = state.copy(loading: false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        user = (await FirebaseAuth.instance.signInWithCredential(cred)).user!;
      }
      _api.setToken(await user.getIdToken());
      final profile = await _api.syncAuth(displayName: user.displayName);
      state = AuthState(profile: profile, loading: false);
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
    }
  }

  Future<void> loginEmail(String email, String password) async {
    state = state.copy(loading: true, error: null);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _api.setToken(await cred.user!.getIdToken());
      final profile = await _api.syncAuth(displayName: cred.user!.displayName);
      state = AuthState(profile: profile, loading: false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        _api.setToken(await cred.user!.getIdToken());
        final profile = await _api.syncAuth();
        state = AuthState(profile: profile, loading: false);
        return;
      }
      state = AuthState(loading: false, error: e.message);
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
    }
  }

  Future<void> updateProfile({
    String? displayName,
    List<String>? allergies,
    List<String>? diets,
  }) async {
    if (displayName != null) {
      await _api.patchMe(displayName: displayName);
    }
    if (allergies != null || diets != null) {
      await _api.patchPreferences(allergies: allergies, diets: diets);
    }
    final profile = await _api.me();
    state = AuthState(profile: profile, loading: false);
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    _api.setToken(null);
    state = const AuthState(loading: false);
  }
}

extension on AuthState {
  AuthState copy({UserProfile? profile, bool? loading, String? error}) =>
      AuthState(
        profile: profile ?? this.profile,
        loading: loading ?? this.loading,
        error: error,
      );
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiProvider));
});

final pantryProvider = FutureProvider<List<PantryItem>>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).pantry();
});

/// `true` mientras el onboarding va por el paso de la despensa: el usuario ya
/// tiene nombre pero aún no debe salir de /onboarding.
final onboardingPendingProvider = StateProvider<bool>((_) => false);

/// Ruta a la que volver tras entrar, por ejemplo una receta compartida.
final returnToProvider = StateProvider<String?>((_) => null);

/// Filtros activos en el feed (tiempo, cocina, dieta).
final feedFiltersProvider = StateProvider<RecipeFilters>(
  (_) => const RecipeFilters(),
);

/// Orden del feed: `false` cronológico, `true` primero lo que se puede cocinar.
final feedByMatchProvider = StateProvider<bool>((_) => false);

/// Feed reducido a las recetas de la gente que sigues.
final feedFollowingProvider = StateProvider<bool>((_) => false);

final feedProvider = FutureProvider<List<RecipeCard>>((ref) async {
  ref.watch(authProvider);
  final filters = ref.watch(feedFiltersProvider);
  final following = ref.watch(feedFollowingProvider);
  return ref.read(apiProvider).feed(filters: filters, following: following);
});

final cuisinesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).cuisines();
});

final shoppingProvider = FutureProvider<List<ShoppingItem>>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).shopping();
});

final statsProvider = FutureProvider<ProfileStats>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).myStats();
});
