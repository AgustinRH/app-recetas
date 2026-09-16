class UserProfile {
  UserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.allergies = const [],
    this.diets = const [],
  });

  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final List<String> allergies;
  final List<String> diets;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final prefs = json['preferences'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Chef',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      allergies: List<String>.from(prefs['allergies'] ?? const []),
      diets: List<String>.from(prefs['diets'] ?? const []),
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
    this.authorName,
    this.matchPct,
    this.missingCount,
  });

  final String id;
  final String title;
  final String? photoUrl;
  final int prepMinutes;
  final String cuisine;
  final String? authorName;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final double? matchPct;
  final int? missingCount;

  factory RecipeCard.fromJson(Map<String, dynamic> json) => RecipeCard(
        id: json['id'] as String,
        title: json['title'] as String,
        photoUrl: json['photoUrl'] as String?,
        prepMinutes: json['prepMinutes'] as int? ?? 0,
        cuisine: json['cuisine'] as String? ?? '',
        authorName: (json['author'] as Map?)?['displayName'] as String?,
        likesCount: json['likesCount'] as int? ?? 0,
        commentsCount: json['commentsCount'] as int? ?? 0,
        isLiked: json['isLiked'] as bool? ?? false,
        isSaved: json['isSaved'] as bool? ?? false,
        matchPct: (json['matchPct'] as num?)?.toDouble(),
        missingCount: json['missingCount'] as int?,
      );
}

class RecipeDetail {
  RecipeDetail({
    required this.card,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.missing,
    this.calories,
    this.dietTags = const [],
  });

  final RecipeCard card;
  final String description;
  final double? calories;
  final List<String> dietTags;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<RecipeIngredient> missing;

  factory RecipeDetail.fromJson(Map<String, dynamic> json) => RecipeDetail(
        card: RecipeCard.fromJson(json),
        description: json['description'] as String? ?? '',
        calories: (json['calories'] as num?)?.toDouble(),
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
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool optional;
  final bool inPantry;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? 'ud',
        optional: json['optional'] as bool? ?? false,
        inPantry: json['inPantry'] as bool? ?? false,
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
