import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../providers.dart';
import '../widgets/recipe_grid_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          CircleAvatar(
            radius: 36,
            child: Text(
              (profile?.displayName ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile?.displayName ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(profile?.email ?? ''),
          const SizedBox(height: 8),
          Text('Dietas: ${(profile?.diets.isEmpty ?? true) ? '—' : profile!.diets.join(', ')}'),
          Text(
            'Alergias: ${(profile?.allergies.isEmpty ?? true) ? '—' : profile!.allergies.join(', ')}',
          ),
          const SizedBox(height: 16),
          const Text('Mis recetas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          _RecipeStrip(
            loader: () => ref.read(apiProvider).myRecipes(),
          ),
          const SizedBox(height: 16),
          const Text('Guardadas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          _RecipeStrip(
            loader: () => ref.read(apiProvider).savedRecipes(),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.push('/preferences'),
            child: const Text('Editar preferencias'),
          ),
        ],
      ),
    );
  }
}

class _RecipeStrip extends StatelessWidget {
  const _RecipeStrip({required this.loader});

  final Future<List<RecipeCard>> Function() loader;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecipeCard>>(
      future: loader(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final items = snap.data!;
        if (items.isEmpty) return const Text('Nada aún');
        return SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(
              width: 140,
              child: RecipeGridCard(recipe: items[i]),
            ),
          ),
        );
      },
    );
  }
}
