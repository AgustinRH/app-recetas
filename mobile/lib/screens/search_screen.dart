import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../widgets/recipe_grid_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final query = TextEditingController();
  bool fromPantry = true;
  List<RecipeCard> results = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final api = ref.read(apiProvider);
      final data = query.text.trim().isEmpty
          ? await api.suggested(fromPantry: fromPantry)
          : await api.search(query.text.trim(), fromPantry: fromPantry);
      setState(() {
        results = data;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sugeridas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: query,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar recetas',
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          SwitchListTile(
            title: const Text('Con lo que tengo'),
            value: fromPantry,
            onChanged: (v) {
              setState(() => fromPantry = v);
              _load();
            },
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: results.length,
                    itemBuilder: (_, i) => RecipeGridCard(recipe: results[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
