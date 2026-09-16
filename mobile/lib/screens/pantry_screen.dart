import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final query = TextEditingController();
  List<Ingredient> suggestions = [];

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => suggestions = []);
      return;
    }
    final hits = await ref.read(apiProvider).ingredients(q: q);
    setState(() => suggestions = hits);
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi despensa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: query,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Añadir ingrediente…',
              ),
              onChanged: _search,
            ),
          ),
          if (suggestions.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: suggestions
                    .map(
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(i.name),
                          onPressed: () async {
                            await ref.read(apiProvider).addPantry(i.id);
                            query.clear();
                            setState(() => suggestions = []);
                            ref.invalidate(pantryProvider);
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: pantry.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Tu despensa está vacía. Añade lo que tienes en casa.'),
                  );
                }
                final grouped = <String, List<PantryItem>>{};
                for (final item in items) {
                  grouped.putIfAbsent(item.ingredient.category, () => []).add(item);
                }
                final categories = grouped.keys.toList()..sort();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  children: [
                    for (final cat in categories) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ...grouped[cat]!.map(
                        (item) => ListTile(
                          title: Text(item.ingredient.name),
                          subtitle: Text('${item.quantity} ${item.unit}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await ref.read(apiProvider).removePantry(item.id);
                              ref.invalidate(pantryProvider);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
