import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  RecipeDetail? detail;
  List<RecipeComment> comments = [];
  final commentCtrl = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    final d = await api.recipe(widget.id);
    final c = await api.comments(widget.id);
    setState(() {
      detail = d;
      comments = c;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading || detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final recipe = detail!;
    return Scaffold(
      appBar: AppBar(title: Text(recipe.card.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: recipe.card.photoUrl == null
                  ? Container(
                      color: terracotta.withValues(alpha: 0.15),
                      child: const Center(child: Text('🍳', style: TextStyle(fontSize: 48))),
                    )
                  : CachedNetworkImage(imageUrl: recipe.card.photoUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${recipe.card.prepMinutes} min · ${recipe.card.cuisine}'
            '${recipe.calories != null ? ' · ${recipe.calories!.round()} kcal' : ''}',
          ),
          if (recipe.card.matchPct != null) ...[
            const SizedBox(height: 8),
            Text(
              'Coincide un ${recipe.card.matchPct!.round()}% con tu despensa',
              style: const TextStyle(fontWeight: FontWeight.w800, color: terracotta),
            ),
          ],
          if (recipe.missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {},
              child: Text(
                'Faltan ${recipe.missing.length} ingredientes → Añadir a la lista',
              ),
            ),
            Text(
              recipe.missing.map((m) => m.name).join(', '),
              style: TextStyle(color: ink.withValues(alpha: 0.7)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  recipe.card.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: terracotta,
                ),
                onPressed: () async {
                  await ref.read(apiProvider).like(widget.id, !recipe.card.isLiked);
                  await _load();
                  ref.invalidate(feedProvider);
                },
              ),
              IconButton(
                icon: Icon(
                  recipe.card.isSaved ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: () async {
                  await ref.read(apiProvider).save(widget.id, !recipe.card.isSaved);
                  await _load();
                },
              ),
            ],
          ),
          Text(recipe.description),
          const SizedBox(height: 16),
          const Text('Ingredientes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ...recipe.ingredients.map(
            (i) => ListTile(
              dense: true,
              leading: Icon(
                i.inPantry ? Icons.check_circle : Icons.radio_button_unchecked,
                color: i.inPantry ? Colors.green : Colors.grey,
              ),
              title: Text(i.name),
              subtitle: Text('${i.quantity} ${i.unit}${i.optional ? ' (opcional)' : ''}'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Pasos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ...recipe.steps.asMap().entries.map(
            (e) => ListTile(
              leading: CircleAvatar(child: Text('${e.key + 1}')),
              title: Text(e.value),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Comentarios', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ...comments.map(
            (c) => ListTile(
              title: Text(c.authorName),
              subtitle: Text(c.body),
            ),
          ),
          TextField(
            controller: commentCtrl,
            decoration: InputDecoration(
              hintText: 'Escribe un comentario',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  if (commentCtrl.text.trim().isEmpty) return;
                  await ref.read(apiProvider).addComment(widget.id, commentCtrl.text.trim());
                  commentCtrl.clear();
                  await _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
