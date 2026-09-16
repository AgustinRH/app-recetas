import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';
import 'models.dart';

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
          ),
        );

  final Dio _dio;
  String? _token;

  void setToken(String? token) {
    _token = token;
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<UserProfile> syncAuth({String? displayName}) async {
    final res = await _dio.post('/auth/sync', data: {
      if (displayName != null) 'displayName': displayName,
    });
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<UserProfile> me() async {
    final res = await _dio.get('/me');
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<UserProfile> patchMe({String? displayName}) async {
    final res = await _dio.patch('/me', data: {
      if (displayName != null) 'displayName': displayName,
    });
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<UserProfile> patchPreferences({
    List<String>? allergies,
    List<String>? diets,
  }) async {
    final res = await _dio.patch('/me/preferences', data: {
      if (allergies != null) 'allergies': allergies,
      if (diets != null) 'diets': diets,
    });
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Ingredient>> ingredients({String? q, String? category}) async {
    final res = await _dio.get('/ingredients', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (category != null) 'category': category,
    });
    return (res.data as List)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PantryItem>> pantry() async {
    final res = await _dio.get('/pantry');
    return (res.data as List)
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PantryItem> addPantry(String ingredientId) async {
    final res = await _dio.post('/pantry', data: {
      'ingredientId': ingredientId,
      'quantity': 1,
      'unit': 'ud',
    });
    return PantryItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> removePantry(String id) => _dio.delete('/pantry/$id');

  Future<List<RecipeCard>> suggested({bool fromPantry = true, String? q}) async {
    final res = await _dio.get(
      fromPantry ? '/recipes/suggested' : '/recipes/search',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
    );
    final data = res.data;
    final list = data is List ? data : (data as Map)['items'] as List? ?? data as List;
    return list
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipeCard>> search(String q, {bool fromPantry = false}) async {
    final res = await _dio.get('/recipes/search', queryParameters: {
      'q': q,
      'fromPantry': fromPantry,
    });
    return (res.data as List)
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipeCard>> feed() async {
    final res = await _dio.get('/feed');
    final items = (res.data as Map)['items'] as List;
    return items
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RecipeDetail> recipe(String id) async {
    final res = await _dio.get('/recipes/$id');
    return RecipeDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RecipeDetail> createRecipe(Map<String, dynamic> body) async {
    final res = await _dio.post('/recipes', data: body);
    return RecipeDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> uploadPhoto(String recipeId, String path) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: 'photo.jpg'),
    });
    final res = await _dio.post('/recipes/$recipeId/photo', data: form);
    return (res.data as Map)['photoUrl'] as String;
  }

  Future<void> like(String id, bool liked) async {
    if (liked) {
      await _dio.post('/recipes/$id/likes');
    } else {
      await _dio.delete('/recipes/$id/likes');
    }
  }

  Future<void> save(String id, bool saved) async {
    if (saved) {
      await _dio.post('/recipes/$id/saves');
    } else {
      await _dio.delete('/recipes/$id/saves');
    }
  }

  Future<List<RecipeComment>> comments(String id) async {
    final res = await _dio.get('/recipes/$id/comments');
    return (res.data as List)
        .map((e) => RecipeComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addComment(String id, String body) async {
    await _dio.post('/recipes/$id/comments', data: {'body': body});
  }

  Future<List<RecipeCard>> myRecipes() async {
    final res = await _dio.get('/me/recipes');
    return (res.data as List)
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipeCard>> savedRecipes() async {
    final res = await _dio.get('/me/saved');
    return (res.data as List)
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void logError(Object error) {
    if (kDebugMode) debugPrint('$error');
  }
}
