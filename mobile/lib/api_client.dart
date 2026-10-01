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

  Future<List<Ingredient>> ingredients({
    String? q,
    String? category,
    int? limit,
  }) async {
    final res = await _dio.get('/ingredients', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (category != null) 'category': category,
      if (limit != null) 'limit': limit,
    });
    return (res.data as List)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> ingredientCategories() async {
    final res = await _dio.get('/ingredients/categories');
    return List<String>.from(res.data as List);
  }

  /// Crea un ingrediente que no está en el catálogo. Si ya existía con ese
  /// nombre, el backend devuelve el existente.
  Future<Ingredient> createIngredient(String name, {String? category}) async {
    final res = await _dio.post('/ingredients', data: {
      'name': name,
      if (category != null) 'category': category,
    });
    return Ingredient.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<PantryItem>> pantry() async {
    final res = await _dio.get('/pantry');
    return (res.data as List)
        .map((e) => PantryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Si el ingrediente ya estaba, el backend actualiza cantidad/unidad.
  Future<PantryItem> addPantry(
    String ingredientId, {
    double quantity = 1,
    String unit = 'ud',
    DateTime? expiresAt,
  }) async {
    final res = await _dio.post('/pantry', data: {
      'ingredientId': ingredientId,
      'quantity': quantity,
      'unit': unit,
      if (expiresAt != null) 'expiresAt': _dateOnly(expiresAt),
    });
    return PantryItem.fromJson(res.data as Map<String, dynamic>);
  }

  /// [clearExpiry] borra la fecha de caducidad.
  Future<PantryItem> updatePantry(
    String id, {
    double? quantity,
    String? unit,
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) async {
    final res = await _dio.patch('/pantry/$id', data: {
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (clearExpiry) 'expiresAt': null,
      if (!clearExpiry && expiresAt != null) 'expiresAt': _dateOnly(expiresAt),
    });
    return PantryItem.fromJson(res.data as Map<String, dynamic>);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> removePantry(String id) => _dio.delete('/pantry/$id');

  Future<List<RecipeCard>> suggested({
    bool fromPantry = true,
    String? q,
    RecipeFilters filters = const RecipeFilters(),
  }) async {
    final res = await _dio.get(
      fromPantry ? '/recipes/suggested' : '/recipes/search',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        ...filters.toQuery(),
      },
    );
    final data = res.data;
    final list = data is List ? data : (data as Map)['items'] as List? ?? data as List;
    return list
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipeCard>> search(
    String q, {
    bool fromPantry = false,
    RecipeFilters filters = const RecipeFilters(),
  }) async {
    final res = await _dio.get('/recipes/search', queryParameters: {
      'q': q,
      'fromPantry': fromPantry,
      ...filters.toQuery(),
    });
    return (res.data as List)
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecipeCard>> feed({
    RecipeFilters filters = const RecipeFilters(),
    bool following = false,
  }) async {
    final res = await _dio.get('/feed', queryParameters: {
      ...filters.toQuery(),
      if (following) 'following': '1',
    });
    final items = (res.data as Map)['items'] as List;
    return items
        .map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> cuisines() async {
    final res = await _dio.get('/recipes/cuisines');
    return List<String>.from(res.data as List);
  }

  // ---- Lista de la compra -------------------------------------------------

  Future<List<ShoppingItem>> shopping() async {
    final res = await _dio.get('/shopping');
    return (res.data as List)
        .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingItem> addShopping(
    String ingredientId, {
    double quantity = 1,
    String unit = 'ud',
  }) async {
    final res = await _dio.post('/shopping', data: {
      'ingredientId': ingredientId,
      'quantity': quantity,
      'unit': unit,
    });
    return ShoppingItem.fromJson(res.data as Map<String, dynamic>);
  }

  /// Añade a la lista lo que falta (o no llega) para la receta.
  /// Devuelve cuántas líneas se añadieron.
  Future<int> addMissingToShopping(String recipeId) async {
    final res = await _dio.post('/shopping/from-recipe/$recipeId');
    return ((res.data as Map)['added'] as List).length;
  }

  Future<ShoppingItem> updateShopping(
    String id, {
    bool? checked,
    double? quantity,
    String? unit,
  }) async {
    final res = await _dio.patch('/shopping/$id', data: {
      if (checked != null) 'checked': checked,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
    });
    return ShoppingItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> removeShopping(String id) => _dio.delete('/shopping/$id');

  Future<void> clearShopping({bool onlyChecked = false}) =>
      _dio.delete('/shopping', queryParameters: {'checked': onlyChecked});

  /// Pasa lo marcado a la despensa. Devuelve cuántas líneas se movieron.
  Future<int> checkoutShopping() async {
    final res = await _dio.post('/shopping/checkout');
    return (res.data as Map)['moved'] as int;
  }

  Future<void> deleteAccount() => _dio.delete('/me');

  Future<ProfileStats> myStats() async {
    final res = await _dio.get('/me/stats');
    return ProfileStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RecipeDetail> recipe(String id) async {
    final res = await _dio.get('/recipes/$id');
    return RecipeDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RecipeDetail> createRecipe(Map<String, dynamic> body) async {
    final res = await _dio.post('/recipes', data: body);
    return RecipeDetail.fromJson(res.data as Map<String, dynamic>);
  }

  /// [bytes] + [filename] funcionan igual en móvil y en web (en web no hay
  /// rutas de fichero, así que `MultipartFile.fromFile` no sirve).
  Future<String> uploadPhoto(
    String recipeId,
    List<int> bytes, {
    String filename = 'photo.jpg',
    String? mimeType,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mimeType != null ? DioMediaType.parse(mimeType) : null,
      ),
    });
    final res = await _dio.post('/recipes/$recipeId/photo', data: form);
    return (res.data as Map)['photoUrl'] as String;
  }

  /// Mensaje legible para el usuario a partir de un error de red/API.
  static String describeError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'];
        if (msg is List) return msg.join('. ');
        return msg.toString();
      }
      if (error.response?.statusCode != null) {
        return 'Error ${error.response!.statusCode} de la API';
      }
      return 'No se pudo conectar con la API';
    }
    return error.toString();
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

  Future<void> markCooked(String id) async {
    await _dio.post('/recipes/$id/cooks');
  }

  Future<void> setFollow(String userId, bool follow) async {
    if (follow) {
      await _dio.post('/users/$userId/follow');
    } else {
      await _dio.delete('/users/$userId/follow');
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

  Future<Map<String, dynamic>> adminSummary() async {
    final res = await _dio.get('/admin/summary');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> adminUsers({String? q}) async {
    final res = await _dio.get('/admin/users', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminSetBanned(String id, bool banned) async {
    await _dio.patch('/admin/users/$id', data: {'banned': banned});
  }

  Future<List<Map<String, dynamic>>> adminRecipes({String? q}) async {
    final res = await _dio.get('/admin/recipes', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminDeleteRecipe(String id) async {
    await _dio.delete('/admin/recipes/$id');
  }

  Future<List<Map<String, dynamic>>> adminComments({String? q}) async {
    final res = await _dio.get('/admin/comments', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminDeleteComment(String id) async {
    await _dio.delete('/admin/comments/$id');
  }

  Future<WeekPlan> planner(String weekStart) async {
    final res = await _dio.get('/planner', queryParameters: {'weekStart': weekStart});
    return WeekPlan.fromJson(res.data as Map<String, dynamic>);
  }

  Future<WeekPlan> setPlanSlot({
    required String weekStart,
    required int dayIndex,
    required String meal,
    String? recipeId,
  }) async {
    final res = await _dio.put('/planner/slots', data: {
      'weekStart': weekStart,
      'dayIndex': dayIndex,
      'meal': meal,
      'recipeId': recipeId,
    });
    return WeekPlan.fromJson(res.data as Map<String, dynamic>);
  }

  /// Pasa a la compra lo que falta para la semana. No duplica lo que ya estaba.
  Future<int> plannerToShopping(String weekStart) async {
    final res = await _dio.post('/planner/shopping', data: {'weekStart': weekStart});
    return (res.data as Map)['count'] as int? ?? 0;
  }

  Future<void> reportRecipe(String id, {required String reason, String note = ''}) async {
    await _dio.post('/recipes/$id/reports', data: {'reason': reason, 'note': note});
  }

  Future<List<Map<String, dynamic>>> adminReports({String? q}) async {
    final res = await _dio.get('/admin/reports', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminDismissReport(String id) async {
    await _dio.patch('/admin/reports/$id');
  }

  void logError(Object error) {
    if (kDebugMode) debugPrint('$error');
  }
}
