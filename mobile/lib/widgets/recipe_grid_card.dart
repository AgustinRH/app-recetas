import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../theme.dart';

/// Tarjeta de receta para rejillas y carruseles.
///
/// Muestra, además de foto y título: coincidencia con la despensa (con color
/// según se pueda cocinar ya, casi, o no), tiempo, dificultad, cocina, dieta,
/// autor y contadores sociales.
class RecipeGridCard extends StatelessWidget {
  const RecipeGridCard({super.key, required this.recipe, this.compact = false});

  final RecipeCard recipe;

  /// Versión reducida para carruseles horizontales (perfil).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = ink.withValues(alpha: 0.6);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _photo(),
                  if (recipe.matchPct != null)
                    Positioned(top: 8, left: 8, child: _matchBadge()),
                  if (recipe.isSaved)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.bookmark, color: Colors.white, size: 20),
                    ),
                  Positioned(
                    bottom: 6,
                    left: 8,
                    right: 8,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _pill(Icons.schedule, '${recipe.prepMinutes} min'),
                        if (!compact) _pill(_difficultyIcon(), recipe.difficulty),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          recipe.isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: recipe.isLiked ? terracotta : muted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.likesCount}',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.mode_comment_outlined, size: 14, color: muted),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.commentsCount}',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const Spacer(),
                        if (recipe.authorName != null)
                          Flexible(
                            child: Text(
                              recipe.authorName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[
      if (recipe.cuisine.isNotEmpty) recipe.cuisine,
      if (recipe.dietTags.isNotEmpty) recipe.dietTags.first,
      if (recipe.calories != null) '${recipe.calories!.round()} kcal',
    ];
    return parts.join(' · ');
  }

  IconData _difficultyIcon() {
    switch (recipe.difficulty) {
      case 'difícil':
        return Icons.whatshot;
      case 'media':
        return Icons.local_fire_department_outlined;
      default:
        return Icons.eco_outlined;
    }
  }

  Widget _photo() {
    if (recipe.photoUrl == null) {
      return Container(
        color: terracotta.withValues(alpha: 0.12),
        child: const Center(
          child: Text('🍳', style: TextStyle(fontSize: 40)),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: recipe.photoUrl!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) =>
          Container(color: terracotta.withValues(alpha: 0.12)),
    );
  }

  Widget _matchBadge() {
    final pct = recipe.matchPct!.round();
    final Color bg;
    final String label;
    if (recipe.canCook) {
      bg = const Color(0xFF2E7D32);
      label = '✓ Puedes cocinarla';
    } else if (recipe.almost) {
      bg = const Color(0xFFEF8F00);
      label = 'Falta${recipe.missingCount == 1 ? '' : 'n'} ${recipe.missingCount}';
    } else {
      bg = Colors.black.withValues(alpha: 0.65);
      label = '$pct%';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
