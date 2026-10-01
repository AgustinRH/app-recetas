class UserProfile {
  UserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.allergies = const [],
    this.diets = const [],
    this.createdAt,
    this.isAdmin = false,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final List<String> allergies;
  final List<String> diets;
  final DateTime? createdAt;
  final bool isAdmin;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final prefs = json['preferences'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Chef',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      allergies: List<String>.from(prefs['allergies'] ?? const []),
      diets: List<String>.from(prefs['diets'] ?? const []),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      isAdmin: json['isAdmin'] == true,
    );
  }

  bool get needsOnboarding => displayName.isEmpty || displayName == 'Chef';
}

class Ingredient {
  Ingredient({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String category;
  final List<String> aliases;

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'Otros',
        aliases: List<String>.from(json['aliases'] ?? const []),
      );
}

class PantryItem {
  PantryItem({
    required this.id,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.ingredient,
    this.expiresAt,
  });

  final String id;
  final String ingredientId;
  final double quantity;
  final String unit;
  final DateTime? expiresAt;
  final Ingredient ingredient;

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
        id: json['id'] as String,
        ingredientId: json['ingredientId'] as String,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? 'ud',
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
        ingredient: Ingredient.fromJson(
          json['ingredient'] as Map<String, dynamic>,
        ),
      );
}

class RecipeCard {
  RecipeCard({
    required this.id,
    required this.title,
    required this.prepMinutes,
    required this.cuisine,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.isSaved,
    this.photoUrl,
    this.authorId,
    this.authorName,
    this.matchPct,
    this.missingCount,
    this.dietTags = const [],
    this.difficulty = 'fácil',
    this.servings = 2,
    this.calories,
    this.ingredientsCount,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? photoUrl;
  final int prepMinutes;
  final String cuisine;
  final String? authorId;
  final String? authorName;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final double? matchPct;
  final int? missingCount;
  final List<String> dietTags;
  final String difficulty;
  final int servings;
  final double? calories;
  final int? ingredientsCount;
  final DateTime? createdAt;

  /// Se puede cocinar ya con lo que hay en la despensa.
  bool get canCook => matchPct != null && matchPct! >= 100;

  /// Casi: faltan uno o dos ingredientes.
  bool get almost =>
      !canCook && missingCount != null && missingCount! > 0 && missingCount! <= 2;

  factory RecipeCard.fromJson(Map<String, dynamic> json) => RecipeCard(
        id: json['id'] as String,
        title: json['title'] as String,
        photoUrl: json['photoUrl'] as String?,
        prepMinutes: json['prepMinutes'] as int? ?? 0,
        cuisine: json['cuisine'] as String? ?? '',
        authorId: (json['author'] as Map?)?['id'] as String?,
        authorName: (json['author'] as Map?)?['displayName'] as String?,
        likesCount: json['likesCount'] as int? ?? 0,
        commentsCount: json['commentsCount'] as int? ?? 0,
        isLiked: json['isLiked'] as bool? ?? false,
        isSaved: json['isSaved'] as bool? ?? false,
        matchPct: (json['matchPct'] as num?)?.toDouble(),
        missingCount: json['missingCount'] as int?,
        dietTags: List<String>.from(json['dietTags'] ?? const []),
        difficulty: json['difficulty'] as String? ?? 'fácil',
        servings: json['servings'] as int? ?? 2,
        calories: (json['calories'] as num?)?.toDouble(),
        ingredientsCount: json['ingredientsCount'] as int?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

class ShoppingItem {
  ShoppingItem({
    required this.id,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.checked,
    required this.ingredient,
    this.recipeId,
  });

  final String id;
  final String ingredientId;
  final double quantity;
  final String unit;
  final bool checked;
  final String? recipeId;
  final Ingredient ingredient;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        ingredientId: json['ingredientId'] as String,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? 'ud',
        checked: json['checked'] as bool? ?? false,
        recipeId: json['recipeId'] as String?,
        ingredient: Ingredient.fromJson(
          json['ingredient'] as Map<String, dynamic>,
        ),
      );
}

class UserBadge {
  const UserBadge({
    required this.code,
    required this.name,
    required this.hint,
    required this.earned,
  });

  final String code;
  final String name;
  final String hint;
  final bool earned;

  factory UserBadge.fromJson(Map<String, dynamic> json) => UserBadge(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        hint: json['hint'] as String? ?? '',
        earned: json['earned'] == true,
      );
}

class ProfileStats {
  const ProfileStats({
    this.recipesCount = 0,
    this.likesReceived = 0,
    this.savedCount = 0,
    this.pantryCount = 0,
    this.cookedCount = 0,
    this.cookedToday = false,
    this.streak = 0,
    this.bestStreak = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.badges = const [],
    this.topCuisines = const [],
  });

  final int recipesCount;
  final int likesReceived;
  final int savedCount;
  final int pantryCount;
  final int cookedCount;
  final bool cookedToday;
  final int streak;
  final int bestStreak;
  final int followersCount;
  final int followingCount;
  final List<UserBadge> badges;
  final List<String> topCuisines;

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
        recipesCount: json['recipesCount'] as int? ?? 0,
        likesReceived: json['likesReceived'] as int? ?? 0,
        savedCount: json['savedCount'] as int? ?? 0,
        pantryCount: json['pantryCount'] as int? ?? 0,
        cookedCount: json['cookedCount'] as int? ?? 0,
        cookedToday: json['cookedToday'] == true,
        streak: json['streak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        followersCount: json['followersCount'] as int? ?? 0,
        followingCount: json['followingCount'] as int? ?? 0,
        badges: (json['badges'] as List? ?? [])
            .map((e) => UserBadge.fromJson(e as Map<String, dynamic>))
            .toList(),
        topCuisines: List<String>.from(json['topCuisines'] ?? const []),
      );
}

/// Filtros compartidos por el feed y la búsqueda.
class RecipeFilters {
  const RecipeFilters({this.maxMinutes, this.cuisine, this.diet});

  final int? maxMinutes;
  final String? cuisine;
  final String? diet;

  bool get isEmpty => maxMinutes == null && cuisine == null && diet == null;
  int get count =>
      (maxMinutes != null ? 1 : 0) +
      (cuisine != null ? 1 : 0) +
      (diet != null ? 1 : 0);

  RecipeFilters copyWith({
    int? maxMinutes,
    String? cuisine,
    String? diet,
    bool clearMinutes = false,
    bool clearCuisine = false,
    bool clearDiet = false,
  }) =>
      RecipeFilters(
        maxMinutes: clearMinutes ? null : (maxMinutes ?? this.maxMinutes),
        cuisine: clearCuisine ? null : (cuisine ?? this.cuisine),
        diet: clearDiet ? null : (diet ?? this.diet),
      );

  Map<String, dynamic> toQuery() => {
        if (maxMinutes != null) 'maxMinutes': maxMinutes,
        if (cuisine != null) 'cuisine': cuisine,
        if (diet != null) 'diet': diet,
      };
}

class RecipeDetail {
  RecipeDetail({
    required this.card,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.missing,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.dietTags = const [],
    this.cookedCount = 0,
    this.cookedToday = false,
    this.followingAuthor = false,
  });

  final RecipeCard card;
  final String description;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final List<String> dietTags;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<RecipeIngredient> missing;
  final int cookedCount;
  final bool cookedToday;
  final bool followingAuthor;

  bool get hasNutrition =>
      calories != null || protein != null || carbs != null || fat != null;

  /// Ingredientes que están pero en cantidad insuficiente.
  List<RecipeIngredient> get insufficient =>
      ingredients.where((i) => i.insufficient && !i.optional).toList();

  factory RecipeDetail.fromJson(Map<String, dynamic> json) => RecipeDetail(
        card: RecipeCard.fromJson(json),
        description: json['description'] as String? ?? '',
        calories: (json['calories'] as num?)?.toDouble(),
        protein: (json['protein'] as num?)?.toDouble(),
        carbs: (json['carbs'] as num?)?.toDouble(),
        fat: (json['fat'] as num?)?.toDouble(),
        dietTags: List<String>.from(json['dietTags'] ?? const []),
        ingredients: (json['ingredients'] as List? ?? [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: (json['steps'] as List? ?? [])
            .map((e) => (e as Map)['body'] as String)
            .toList(),
        missing: (json['missingIngredients'] as List? ?? [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        cookedCount: json['cookedCount'] as int? ?? 0,
        cookedToday: json['cookedToday'] == true,
        followingAuthor: json['followingAuthor'] == true,
      );
}

class RecipeIngredient {
  RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.optional = false,
    this.inPantry = false,
    bool? enough,
    this.pantryQuantity,
    this.pantryUnit,
    this.category = 'Otros',
  }) : enough = enough ?? inPantry;

  final String id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final bool optional;

  /// Está en la despensa, aunque no llegue la cantidad.
  final bool inPantry;

  /// Está y la cantidad cubre lo que pide la receta.
  final bool enough;
  final double? pantryQuantity;
  final String? pantryUnit;

  /// Está pero no hay suficiente.
  bool get insufficient => inPantry && !enough;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? 'Otros',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? 'ud',
        optional: json['optional'] as bool? ?? false,
        inPantry: json['inPantry'] as bool? ?? false,
        enough: json['enough'] as bool?,
        pantryQuantity: (json['pantryQuantity'] as num?)?.toDouble(),
        pantryUnit: json['pantryUnit'] as String?,
      );
}

class RecipeComment {
  RecipeComment({
    required this.id,
    required this.body,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String body;
  final String authorName;
  final DateTime createdAt;

  factory RecipeComment.fromJson(Map<String, dynamic> json) => RecipeComment(
        id: json['id'] as String,
        body: json['body'] as String,
        authorName: (json['author'] as Map?)?['displayName'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class PlanRecipe {
  PlanRecipe({
    required this.id,
    required this.title,
    this.photoUrl,
    this.prepMinutes = 0,
    this.cuisine = '',
    this.authorName,
  });

  final String id;
  final String title;
  final String? photoUrl;
  final int prepMinutes;
  final String cuisine;
  final String? authorName;

  factory PlanRecipe.fromJson(Map<String, dynamic> json) => PlanRecipe(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        photoUrl: json['photoUrl'] as String?,
        prepMinutes: json['prepMinutes'] as int? ?? 0,
        cuisine: json['cuisine'] as String? ?? '',
        authorName: json['authorName'] as String?,
      );
}

class PlanGap {
  PlanGap({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;

  factory PlanGap.fromJson(Map<String, dynamic> json) => PlanGap(
        ingredientId: json['ingredientId'] as String,
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? 'ud',
      );
}

class PlanSlot {
  PlanSlot({required this.dayIndex, required this.meal, this.recipe});

  final int dayIndex;
  final String meal;
  final PlanRecipe? recipe;

  factory PlanSlot.fromJson(Map<String, dynamic> json) => PlanSlot(
        dayIndex: json['dayIndex'] as int? ?? 0,
        meal: json['meal'] as String? ?? 'comida',
        recipe: json['recipe'] == null
            ? null
            : PlanRecipe.fromJson(json['recipe'] as Map<String, dynamic>),
      );
}

class WeekPlan {
  WeekPlan({required this.weekStart, required this.slots, required this.gaps});

  final String weekStart;
  final List<PlanSlot> slots;
  final List<PlanGap> gaps;

  PlanRecipe? recipeAt(int day, String meal) {
    for (final slot in slots) {
      if (slot.dayIndex == day && slot.meal == meal) return slot.recipe;
    }
    return null;
  }

  factory WeekPlan.fromJson(Map<String, dynamic> json) => WeekPlan(
        weekStart: json['weekStart'] as String,
        slots: (json['slots'] as List? ?? [])
            .map((e) => PlanSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        gaps: (json['gaps'] as List? ?? [])
            .map((e) => PlanGap.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
