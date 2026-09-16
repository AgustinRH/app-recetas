import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/recipe_grid_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('DishToday')),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar el feed\n$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Aún no hay recetas. ¡Publica la primera!'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(feedProvider),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => RecipeGridCard(recipe: items[i]),
            ),
          );
        },
      ),
    );
  }
}
