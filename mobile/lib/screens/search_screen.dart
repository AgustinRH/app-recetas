import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/recipe_grid_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final query = TextEditingController();
  bool fromPantry = true;
  RecipeFilters filters = const RecipeFilters();
  List<RecipeCard> results = [];
  bool loading = true;
  String? error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final q = query.text.trim();
      final data = q.isEmpty
          ? await api.suggested(fromPantry: fromPantry, filters: filters)
          : await api.search(q, fromPantry: fromPantry, filters: filters);
      if (!mounted) return;
      setState(() {
        results = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'No se pudieron cargar las recetas';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuisines = ref.watch(cuisinesProvider).value ?? const <String>[];
    final q = query.text.trim();
    return Scaffold(
      appBar: AppBar(title: Text(fromPantry ? 'Sugeridas para ti' : 'Buscar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por nombre o descripción',
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          query.clear();
                          _load();
                        },
                      ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _load(),
            ),
          ),
          RecipeFilterBar(
            filters: filters,
            cuisines: cuisines,
            onChanged: (f) {
              setState(() => filters = f);
              _load();
            },
            leading: [
              FilterChip(
                avatar: const Icon(Icons.kitchen_outlined, size: 16),
                label: const Text('Con lo que tengo'),
                selected: fromPantry,
                onSelected: (v) {
                  setState(() => fromPantry = v);
                  _load();
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _summary(),
                    style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  String _summary() {
    if (loading) return 'Buscando…';
    final n = results.length;
    final base = n == 1 ? '1 receta' : '$n recetas';
    if (fromPantry) {
      final ready = results.where((r) => r.canCook).length;
      if (ready > 0) {
        return '$base · $ready con todo lo necesario · ordenadas por coincidencia';
      }
      return '$base · ordenadas por coincidencia con tu despensa';
    }
    return base;
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                'Sin resultados',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                filters.isEmpty
                    ? 'Prueba con otra palabra.'
                    : 'Prueba a quitar algún filtro.',
                style: TextStyle(color: ink.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: results.length,
      itemBuilder: (_, i) => RecipeGridCard(recipe: results[i]),
    );
  }
}
