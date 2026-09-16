import 'package:firebase_auth/firebase_auth.dart';
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
      final user = (await FirebaseAuth.instance.signInWithCredential(cred)).user!;
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

final feedProvider = FutureProvider<List<RecipeCard>>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).feed();
});
