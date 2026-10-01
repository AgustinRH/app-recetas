import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/recipe_grid_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final filters = ref.watch(feedFiltersProvider);
    final byMatch = ref.watch(feedByMatchProvider);
    final following = ref.watch(feedFollowingProvider);
    final cuisines = ref.watch(cuisinesProvider).value ?? const <String>[];
    final pantry = ref.watch(pantryProvider).value;
    final name = ref.watch(authProvider).profile?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('DishToday'),
        actions: [
          IconButton(
            tooltip: 'Plan de la semana',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/planner'),
          ),
          IconButton(
            tooltip: 'Lista de la compra',
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push('/shopping'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedProvider);
          ref.invalidate(pantryProvider);
          await ref.read(feedProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Greeting(name: name, pantryCount: pantry?.length),
            ),
            SliverToBoxAdapter(
              child: RecipeFilterBar(
                filters: filters,
                cuisines: cuisines,
                onChanged: (f) =>
                    ref.read(feedFiltersProvider.notifier).state = f,
                leading: [
                  FilterChip(
                    avatar: const Icon(Icons.kitchen_outlined, size: 16),
                    label: const Text('Con lo que tengo'),
                    selected: byMatch,
                    onSelected: (v) =>
                        ref.read(feedByMatchProvider.notifier).state = v,
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: const Text('Siguiendo'),
                    selected: following,
                    onSelected: (v) =>
                        ref.read(feedFollowingProvider.notifier).state = v,
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ...feed.when(
              loading: () => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No se pudo cargar el feed\n$e')),
                ),
              ],
              data: (items) => _sections(context, items, byMatch, filters, following),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    List<RecipeCard> items,
    bool byMatch,
    RecipeFilters filters,
    bool following,
  ) {
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Empty(filtered: !filters.isEmpty, following: following),
        ),
      ];
    }
    if (!byMatch) {
      return [_grid(items), const SliverToBoxAdapter(child: SizedBox(height: 88))];
    }
    final ready = items.where((r) => r.canCook).toList();
    final almost = items.where((r) => r.almost).toList();
    final rest = items
        .where((r) => !r.canCook && !r.almost)
        .toList()
      ..sort((a, b) => (b.matchPct ?? 0).compareTo(a.matchPct ?? 0));
    return [
      if (ready.isNotEmpty) ...[
        _header('Puedes cocinar ya', '${ready.length}', const Color(0xFF2E7D32)),
        _grid(ready),
      ],
      if (almost.isNotEmpty) ...[
        _header('Te falta poco', '${almost.length}', const Color(0xFFEF8F00)),
        _grid(almost),
      ],
      if (rest.isNotEmpty) ...[
        _header(
          ready.isEmpty && almost.isEmpty ? 'Todas las recetas' : 'Para otro día',
          '${rest.length}',
          ink.withValues(alpha: 0.5),
        ),
        _grid(rest),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 88)),
    ];
  }

  Widget _header(String title, String count, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Container(width: 4, height: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(count, style: TextStyle(color: ink.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<RecipeCard> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => RecipeGridCard(recipe: items[i]),
          childCount: items.length,
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, this.pantryCount});

  final String name;
  final int? pantryCount;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final saludo = hour < 13
        ? 'Buenos días'
        : hour < 21
            ? 'Buenas tardes'
            : 'Buenas noches';
    final sub = pantryCount == null
        ? '¿Qué cocinamos hoy?'
        : pantryCount == 0
            ? 'Tu despensa está vacía: añade lo que tienes y te sugerimos recetas.'
            : 'Tienes $pantryCount ingrediente${pantryCount == 1 ? '' : 's'} en la despensa. ¿Qué cocinamos hoy?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? '$saludo 👋' : '$saludo, $name 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: ink.withValues(alpha: 0.65))),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, this.following = false});

  final bool filtered;
  final bool following;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🥣', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            following
                ? 'Aquí verás las recetas de quien sigues.'
                : filtered
                    ? 'Ninguna receta cumple esos filtros.'
                    : 'Aún no hay recetas. ¡Publica la primera!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (filtered) ...[
            const SizedBox(height: 8),
            Text(
              'Prueba a quitar alguno.',
              style: TextStyle(color: ink.withValues(alpha: 0.6)),
            ),
          ],
        ],
      ),
    );
  }
}
