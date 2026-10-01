import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/quantity_dialog.dart';

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
  String? error;

  /// Raciones elegidas por el usuario para escalar cantidades.
  int? servings;

  /// Pasos marcados como hechos (modo cocina).
  final done = <int>{};
  bool addingToList = false;
  bool cooking = false;
  bool reported = false;

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
    try {
      final api = ref.read(apiProvider);
      final d = await api.recipe(widget.id);
      final c = await api.comments(widget.id);
      if (!mounted) return;
      setState(() {
        detail = d;
        comments = c;
        servings ??= d.card.servings;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = ApiClient.describeError(e);
      });
    }
  }

  double get _scale {
    final base = detail?.card.servings ?? 1;
    if (base <= 0 || servings == null) return 1;
    return servings! / base;
  }

  String _qty(double q, String unit) =>
      '${formatQuantity(q * _scale)} $unit';

  Future<void> _report(String title) async {
    final result = await showDialog<_ReportDraft>(
      context: context,
      builder: (_) => _ReportDialog(title: title),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(apiProvider).reportRecipe(
            widget.id,
            reason: result.reason,
            note: result.note,
          );
      if (!mounted) return;
      setState(() => reported = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denuncia enviada. La revisaremos.')),
      );
    } catch (e) {
      final message = ApiClient.describeError(e);
      if (message.contains('Ya has denunciado')) {
        setState(() => reported = true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _addMissingToList() async {
    setState(() => addingToList = true);
    try {
      final n = await ref.read(apiProvider).addMissingToShopping(widget.id);
      ref.invalidate(shoppingProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 1
                ? '1 ingrediente añadido a la lista de la compra'
                : '$n ingredientes añadidos a la lista de la compra',
          ),
          action: SnackBarAction(
            label: 'Ver lista',
            onPressed: () => context.push('/shopping'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.describeError(e))),
      );
    } finally {
      if (mounted) setState(() => addingToList = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(error ?? 'No se pudo cargar la receta')),
      );
    }
    final r = detail!;
    final card = r.card;
    final toBuy = [...r.missing, ...r.insufficient.where((i) => !r.missing.any((m) => m.id == i.id))];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            actions: [
              IconButton(
                tooltip: 'Compartir',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(card.title),
              ),
              if (!ref.watch(authProvider).isLoggedIn)
                TextButton(
                  onPressed: _enter,
                  child: const Text('Entrar', style: TextStyle(color: Colors.white)),
                ),
              if (ref.watch(authProvider).isLoggedIn &&
                  card.authorId != ref.watch(authProvider).profile?.id)
                IconButton(
                  tooltip: reported ? 'Ya denunciada' : 'Denunciar',
                  icon: Icon(reported ? Icons.flag : Icons.flag_outlined),
                  onPressed: reported ? null : () => _report(card.title),
                ),
              IconButton(
                tooltip: card.isSaved ? 'Quitar de guardadas' : 'Guardar',
                icon: Icon(card.isSaved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () async {
                  if (!ref.read(authProvider).isLoggedIn) {
                    _enter();
                    return;
                  }
                  await ref.read(apiProvider).save(widget.id, !card.isSaved);
                  await _load();
                  ref.invalidate(feedProvider);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  card.photoUrl == null
                      ? Container(
                          color: terracotta.withValues(alpha: 0.15),
                          child: const Center(
                            child: Text('🍳', style: TextStyle(fontSize: 64)),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: card.photoUrl!,
                          fit: BoxFit.cover,
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black26, Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (card.authorName != null)
                          Text(
                            'por ${card.authorName}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _infoChips(card, r),
                if (card.authorId != null &&
                    card.authorId != ref.watch(authProvider).profile?.id) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _toggleFollow,
                      icon: Icon(
                        r.followingAuthor ? Icons.check : Icons.person_add_alt_1_outlined,
                      ),
                      label: Text(
                        r.followingAuthor
                            ? 'Siguiendo'
                            : 'Seguir a ${card.authorName ?? 'este chef'}',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (card.matchPct != null) _matchCard(r, toBuy),
                if (r.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    r.description,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                _socialRow(card),
                const SizedBox(height: 12),
                _cookButton(r),
                const Divider(height: 32),
                _ingredientsHeader(card),
                const SizedBox(height: 4),
                ...r.ingredients.map(_ingredientTile),
                if (r.hasNutrition) ...[
                  const Divider(height: 32),
                  _sectionTitle('Información nutricional'),
                  const SizedBox(height: 4),
                  Text(
                    'Por ración',
                    style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _nutrition(r),
                ],
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(child: _sectionTitle('Preparación')),
                    if (done.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(done.clear),
                        child: const Text('Reiniciar'),
                      ),
                  ],
                ),
                Text(
                  '${r.steps.length} paso${r.steps.length == 1 ? '' : 's'} · toca cada uno al terminarlo',
                  style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...r.steps.asMap().entries.map((e) => _stepTile(e.key, e.value)),
                if (r.steps.isNotEmpty && done.length == r.steps.length)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Text('🎉', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '¡Listo! Que aproveche.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 32),
                _sectionTitle(
                  comments.isEmpty
                      ? 'Comentarios'
                      : 'Comentarios (${comments.length})',
                ),
                const SizedBox(height: 8),
                if (comments.isEmpty)
                  Text(
                    'Sé el primero en comentar.',
                    style: TextStyle(color: ink.withValues(alpha: 0.6)),
                  ),
                ...comments.map(_commentTile),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  textInputAction: TextInputAction.send,
                  readOnly: !ref.watch(authProvider).isLoggedIn,
                  onTap: ref.watch(authProvider).isLoggedIn ? null : _enter,
                  onSubmitted: (_) => _sendComment(),
                  decoration: InputDecoration(
                    hintText: ref.watch(authProvider).isLoggedIn
                        ? 'Escribe un comentario'
                        : 'Entra para comentar',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendComment,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendComment() async {
    if (!ref.read(authProvider).isLoggedIn) {
      _enter();
      return;
    }
    final text = commentCtrl.text.trim();
    if (text.isEmpty) return;
    await ref.read(apiProvider).addComment(widget.id, text);
    commentCtrl.clear();
    await _load();
  }

  // ---- Secciones ----------------------------------------------------------

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      );

  Widget _infoChips(RecipeCard card, RecipeDetail r) {
    Widget chip(IconData icon, String label) => Chip(
          avatar: Icon(icon, size: 16),
          label: Text(label),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        );
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        chip(Icons.schedule, '${card.prepMinutes} min'),
        chip(Icons.speed, card.difficulty),
        chip(Icons.public, card.cuisine),
        chip(Icons.restaurant, '${card.servings} ración${card.servings == 1 ? '' : 'es'}'),
        if (r.calories != null) chip(Icons.bolt, '${r.calories!.round()} kcal'),
        ...r.dietTags.map((t) => chip(Icons.eco_outlined, t)),
      ],
    );
  }

  Widget _matchCard(RecipeDetail r, List<RecipeIngredient> toBuy) {
    final pct = r.card.matchPct!.round();
    final Color color = pct >= 100
        ? const Color(0xFF2E7D32)
        : pct >= 60
            ? const Color(0xFFEF8F00)
            : terracotta;
    final String headline = pct >= 100
        ? '¡Tienes todo lo necesario!'
        : toBuy.length == 1
            ? 'Te falta 1 ingrediente'
            : 'Te faltan ${toBuy.length} ingredientes';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          if (toBuy.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: toBuy
                  .map(
                    (m) => Chip(
                      label: Text(_missingLabel(m)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: color.withValues(alpha: 0.08),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: addingToList ? null : _addMissingToList,
                icon: addingToList
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart),
                label: const Text('Añadir lo que falta a la lista de la compra'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Tomate (tienes 2 ud de 6)" o solo "Pepino" si no hay nada.
  String _missingLabel(RecipeIngredient m) {
    if (!m.insufficient || m.pantryQuantity == null) return m.name;
    return '${m.name} (tienes ${formatQuantity(m.pantryQuantity!)} ${m.pantryUnit} '
        'de ${formatQuantity(m.quantity)} ${m.unit})';
  }

  Future<void> _toggleFollow() async {
    if (!ref.read(authProvider).isLoggedIn) {
      _enter();
      return;
    }
    final authorId = detail?.card.authorId;
    if (authorId == null) return;
    final next = !(detail?.followingAuthor ?? false);
    try {
      await ref.read(apiProvider).setFollow(authorId, next);
      ref.invalidate(statsProvider);
      ref.invalidate(feedProvider);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.describeError(e))),
      );
    }
  }

  void _enter() {
    ref.read(returnToProvider.notifier).state = '/recipe/${widget.id}';
    context.go('/login');
  }

  Future<void> _share(String title) async {
    final link = '${Uri.base.origin}/#/recipe/${widget.id}';
    Clipboard.setData(ClipboardData(text: '$title\n$link')).catchError((_) {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado')),
    );
  }

  Widget _cookButton(RecipeDetail recipe) {
    final done = recipe.cookedToday;
    final times = recipe.cookedCount;
    return FilledButton.icon(
      onPressed: !ref.watch(authProvider).isLoggedIn
          ? _enter
          : done || cooking
              ? null
              : _cook,
      icon: Icon(done ? Icons.check : Icons.restaurant_outlined),
      label: Text(
        done
            ? 'Cocinada hoy'
            : times > 0
                ? 'La he cocinado · $times'
                : 'La he cocinado',
      ),
    );
  }

  Future<void> _cook() async {
    setState(() => cooking = true);
    try {
      await ref.read(apiProvider).markCooked(widget.id);
      ref.invalidate(statsProvider);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apuntada. Que aproveche.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.describeError(e))),
      );
    } finally {
      if (mounted) setState(() => cooking = false);
    }
  }

  Widget _socialRow(RecipeCard card) {
    return Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: () async {
            if (!ref.read(authProvider).isLoggedIn) {
              _enter();
              return;
            }
            await ref.read(apiProvider).like(widget.id, !card.isLiked);
            await _load();
            ref.invalidate(feedProvider);
          },
          icon: Icon(
            card.isLiked ? Icons.favorite : Icons.favorite_border,
            color: terracotta,
          ),
          label: Text('${card.likesCount}'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () async {
            if (!ref.read(authProvider).isLoggedIn) {
              _enter();
              return;
            }
            await ref.read(apiProvider).save(widget.id, !card.isSaved);
            await _load();
          },
          icon: Icon(card.isSaved ? Icons.bookmark : Icons.bookmark_border),
          label: Text(card.isSaved ? 'Guardada' : 'Guardar'),
        ),
        const Spacer(),
        Icon(Icons.mode_comment_outlined, size: 18, color: ink.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text('${card.commentsCount}', style: TextStyle(color: ink.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _ingredientsHeader(RecipeCard card) {
    final s = servings ?? card.servings;
    return Row(
      children: [
        Expanded(child: _sectionTitle('Ingredientes')),
        IconButton(
          tooltip: 'Menos raciones',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: s > 1 ? () => setState(() => servings = s - 1) : null,
        ),
        Text(
          '$s ración${s == 1 ? '' : 'es'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        IconButton(
          tooltip: 'Más raciones',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: s < 50 ? () => setState(() => servings = s + 1) : null,
        ),
      ],
    );
  }

  Widget _ingredientTile(RecipeIngredient i) {
    final guest = !ref.watch(authProvider).isLoggedIn;
    final IconData icon;
    final Color color;
    String status = '';
    if (guest) {
      icon = Icons.circle_outlined;
      color = ink.withValues(alpha: 0.45);
      status = '';
    } else if (i.enough) {
      icon = Icons.check_circle;
      color = const Color(0xFF2E7D32);
      status = 'en la despensa';
    } else if (i.insufficient) {
      icon = Icons.error_outline;
      color = Colors.orange.shade800;
      status = i.pantryQuantity != null
          ? 'tienes ${formatQuantity(i.pantryQuantity!)} ${i.pantryUnit}'
          : 'no hay suficiente';
    } else {
      icon = Icons.radio_button_unchecked;
      color = Colors.grey;
      status = i.optional ? 'opcional' : 'te falta';
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        i.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: i.optional && !i.inPantry ? ink.withValues(alpha: 0.6) : null,
        ),
      ),
      subtitle: Text(
        '${i.category}${i.optional ? ' · opcional' : ''}${status.isEmpty ? '' : ' · $status'}',
        style: TextStyle(color: color == Colors.grey ? ink.withValues(alpha: 0.55) : color),
      ),
      trailing: Text(
        _qty(i.quantity, i.unit),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }

  Widget _nutrition(RecipeDetail r) {
    Widget cell(String label, double? v, String unit, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  v == null ? '—' : '${formatQuantity(v)}$unit',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16),
                ),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        cell('kcal', r.calories, '', terracotta),
        const SizedBox(width: 8),
        cell('proteína', r.protein, ' g', const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        cell('hidratos', r.carbs, ' g', const Color(0xFFEF8F00)),
        const SizedBox(width: 8),
        cell('grasas', r.fat, ' g', const Color(0xFF6A1B9A)),
      ],
    );
  }

  Widget _stepTile(int index, String body) {
    final isDone = done.contains(index);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => isDone ? done.remove(index) : done.add(index)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDone ? const Color(0xFF2E7D32) : terracotta,
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  body,
                  style: TextStyle(
                    height: 1.35,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? ink.withValues(alpha: 0.5) : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentTile(RecipeComment c) {
    final initial = c.authorName.isEmpty ? '?' : c.authorName[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, child: Text(initial)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relative(c.createdAt),
                      style: TextStyle(color: ink.withValues(alpha: 0.5), fontSize: 12),
                    ),
                  ],
                ),
                Text(c.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    if (diff.inDays < 30) return 'hace ${diff.inDays} d';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _ReportDraft {
  const _ReportDraft(this.reason, this.note);
  final String reason;
  final String note;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.title});
  final String title;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const reasons = <(String, String)>[
    ('inapropiado', 'Contenido inapropiado'),
    ('spam', 'Spam o publicidad'),
    ('incorrecta', 'Receta incorrecta o peligrosa'),
    ('derechos', 'Derechos de la foto o el texto'),
    ('otro', 'Otro'),
  ];

  String reason = 'inapropiado';
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Denunciar receta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: reason,
              onChanged: (value) {
                if (value != null) setState(() => reason = value);
              },
              child: Column(
                children: [
                  for (final item in reasons)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: item.$1,
                      title: Text(item.$2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Detalle opcional',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ReportDraft(reason, note.text.trim())),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
