import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../providers.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final prep = TextEditingController(text: '20');
  final steps = TextEditingController();
  final ingredientQuery = TextEditingController();
  final selected = <Ingredient>[];
  List<Ingredient> hits = [];
  String? photoPath;
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    prep.dispose();
    steps.dispose();
    ingredientQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar receta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: prep,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutos'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final file = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (file != null) setState(() => photoPath = file.path);
            },
            icon: const Icon(Icons.photo),
            label: Text(photoPath == null ? 'Añadir foto' : 'Foto seleccionada'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ingredientQuery,
            decoration: const InputDecoration(labelText: 'Ingrediente del catálogo'),
            onChanged: (q) async {
              if (q.isEmpty) {
                setState(() => hits = []);
                return;
              }
              final list = await ref.read(apiProvider).ingredients(q: q);
              setState(() => hits = list);
            },
          ),
          Wrap(
            spacing: 8,
            children: hits
                .map(
                  (i) => ActionChip(
                    label: Text(i.name),
                    onPressed: () {
                      setState(() {
                        if (!selected.any((s) => s.id == i.id)) selected.add(i);
                        hits = [];
                        ingredientQuery.clear();
                      });
                    },
                  ),
                )
                .toList(),
          ),
          Wrap(
            spacing: 8,
            children: selected
                .map(
                  (i) => Chip(
                    label: Text(i.name),
                    onDeleted: () => setState(() => selected.remove(i)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: steps,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Pasos (uno por línea)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final created = await ref.read(apiProvider).createRecipe({
                        'title': title.text.trim(),
                        'description': description.text.trim(),
                        'prepMinutes': int.tryParse(prep.text) ?? 20,
                        'ingredients': selected
                            .map((i) => {
                                  'ingredientId': i.id,
                                  'quantity': 1,
                                  'unit': 'ud',
                                })
                            .toList(),
                        'steps': steps.text
                            .split('\n')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      });
                      if (photoPath != null) {
                        await ref.read(apiProvider).uploadPhoto(created.card.id, photoPath!);
                      }
                      ref.invalidate(feedProvider);
                      if (context.mounted) context.go('/recipe/${created.card.id}');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No se pudo publicar: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Publicando…' : 'Publicar'),
          ),
        ],
      ),
    );
  }
}
