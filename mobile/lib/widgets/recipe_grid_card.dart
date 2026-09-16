import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../theme.dart';

class RecipeGridCard extends StatelessWidget {
  const RecipeGridCard({super.key, required this.recipe});

  final RecipeCard recipe;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  recipe.photoUrl == null
                      ? Container(
                          color: terracotta.withValues(alpha: 0.15),
                          child: const Center(
                            child: Text('🍳', style: TextStyle(fontSize: 40)),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: recipe.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: terracotta.withValues(alpha: 0.15),
                          ),
                        ),
                  if (recipe.matchPct != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${recipe.matchPct!.round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recipe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${recipe.prepMinutes} min · ${recipe.likesCount} ♥',
            style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
