import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/create_ingredient_dialog.dart';
import '../widgets/quantity_dialog.dart';
import 'shopping_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shoppingCount = ref.watch(shoppingProvider).value?.where((i) => !i.checked).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cocina'),
        bottom: TabBar(
          controller: tabs,
          tabs: [
            const Tab(icon: Icon(Icons.kitchen_outlined), text: 'Despensa'),
            Tab(
              icon: Badge(
                isLabelVisible: shoppingCount > 0,
                label: Text('$shoppingCount'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              text: 'Lista de la compra',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: const [_PantryTab(), ShoppingListView()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Estado de frescura de un ingrediente según su fecha de caducidad.
enum Freshness { none, ok, soon, expired }

Freshness freshnessOf(PantryItem item) {
  final d = item.expiresAt;
  if (d == null) return Freshness.none;
  final today = DateTime.now();
  final days = DateTime(d.year, d.month, d.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (days < 0) return Freshness.expired;
  if (days <= 3) return Freshness.soon;
  return Freshness.ok;
}

String expiryText(PantryItem item) {
  final d = item.expiresAt;
  if (d == null) return '';
  final today = DateTime.now();
  final days = DateTime(d.year, d.month, d.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (days < 0) return 'caducado hace ${-days} d';
  if (days == 0) return 'caduca hoy';
  if (days == 1) return 'caduca mañana';
  if (days <= 30) return 'caduca en $days d';
  return 'caduca el ${d.day}/${d.month}';
}

class _PantryTab extends ConsumerStatefulWidget {
  const _PantryTab();

  @override
  ConsumerState<_PantryTab> createState() => _PantryTabState();
}

class _PantryTabState extends ConsumerState<_PantryTab> {
  final query = TextEditingController();
  List<Ingredient> suggestions = [];
  bool searched = false;

  /// Filtro de categoría activo (null = todas). "⚠" = solo los que caducan.
  String? category;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        suggestions = [];
        searched = false;
      });
      return;
    }
    final hits = await ref.read(apiProvider).ingredients(q: q.trim());
    if (!mounted || query.text.trim() != q.trim()) return;
    setState(() {
      suggestions = hits;
      searched = true;
    });
  }

  bool get _exactHit {
    final q = query.text.trim().toLowerCase();
    return suggestions.any((i) => i.name.toLowerCase() == q);
  }

  Future<void> _createAndAdd(List<PantryItem> current) async {
    final created = await showCreateIngredientDialog(
      context,
      api: ref.read(apiProvider),
      initialName: query.text,
    );
    if (created == null || !mounted) return;
    await _add(created, current);
  }

  void _toast(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _add(Ingredient ingredient, List<PantryItem> current) async {
    PantryItem? existing;
    for (final p in current) {
      if (p.ingredientId == ingredient.id) existing = p;
    }
    final result = await showQuantityDialog(
      context,
      title: ingredient.name,
      initialQuantity: existing?.quantity ?? 1,
      initialUnit: existing?.unit ?? 'ud',
      confirmLabel: existing == null ? 'Añadir' : 'Actualizar',
      withExpiry: true,
      initialExpiry: existing?.expiresAt,
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await ref.read(apiProvider).addPantry(
              ingredient.id,
              quantity: result.quantity,
              unit: result.unit,
              expiresAt: result.expiresAt,
            );
      } else {
        await ref.read(apiProvider).updatePantry(
              existing.id,
              quantity: result.quantity,
              unit: result.unit,
              expiresAt: result.expiresAt,
              clearExpiry: result.expiresAt == null && existing.expiresAt != null,
            );
      }
      query.clear();
      if (mounted) {
        setState(() {
          suggestions = [];
          searched = false;
        });
      }
      ref.invalidate(pantryProvider);
      ref.invalidate(feedProvider);
    } catch (e) {
      if (mounted) _toast('No se pudo guardar: ${ApiClient.describeError(e)}');
    }
  }

  Future<void> _edit(PantryItem item) async {
    final result = await showQuantityDialog(
      context,
      title: item.ingredient.name,
      initialQuantity: item.quantity,
      initialUnit: item.unit,
      withExpiry: true,
      initialExpiry: item.expiresAt,
    );
    if (result == null) return;
    try {
      await ref.read(apiProvider).updatePantry(
            item.id,
            quantity: result.quantity,
            unit: result.unit,
            expiresAt: result.expiresAt,
            clearExpiry: result.expiresAt == null && item.expiresAt != null,
          );
      ref.invalidate(pantryProvider);
      ref.invalidate(feedProvider);
    } catch (e) {
      if (mounted) _toast('No se pudo guardar: ${ApiClient.describeError(e)}');
    }
  }

  Future<void> _remove(PantryItem item) async {
    try {
      await ref.read(apiProvider).removePantry(item.id);
      ref.invalidate(pantryProvider);
      ref.invalidate(feedProvider);
      if (mounted) {
        _toast(
          '${item.ingredient.name} quitado de la despensa',
          action: SnackBarAction(
            label: 'A la lista',
            onPressed: () => _toShopping(item),
          ),
        );
      }
    } catch (e) {
      if (mounted) _toast(ApiClient.describeError(e));
    }
  }

  Future<void> _toShopping(PantryItem item) async {
    try {
      await ref.read(apiProvider).addShopping(
            item.ingredientId,
            quantity: item.quantity > 0 ? item.quantity : 1,
            unit: item.unit,
          );
      ref.invalidate(shoppingProvider);
      if (mounted) _toast('${item.ingredient.name} añadido a la lista de la compra');
    } catch (e) {
      if (mounted) _toast(ApiClient.describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: query,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Añadir ingrediente…',
            ),
            onChanged: _search,
          ),
        ),
        if (searched && query.text.trim().isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final i in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(i.name),
                      onPressed: () => _add(i, pantry.valueOrNull ?? const []),
                    ),
                  ),
                if (!_exactHit)
                  ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text('Crear «${query.text.trim()}»'),
                    onPressed: () => _createAndAdd(pantry.valueOrNull ?? const []),
                  ),
              ],
            ),
          ),
        Expanded(
          child: pantry.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: _list,
          ),
        ),
      ],
    );
  }

  Widget _list(List<PantryItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧺', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                'Tu despensa está vacía',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Busca arriba lo que tienes en casa y lo usaremos para sugerirte recetas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ink.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }

    // Lo agotado se cuenta aparte aunque además tenga fecha pasada.
    final expiring = items
        .where((i) =>
            i.quantity > 0 &&
            (freshnessOf(i) == Freshness.soon || freshnessOf(i) == Freshness.expired))
        .length;
    final out = items.where((i) => i.quantity <= 0).length;
    final categories = items.map((i) => i.ingredient.category).toSet().toList()..sort();
    if (category != null && category != '⚠' && !categories.contains(category)) {
      category = null;
    }

    final visible = items.where((i) {
      if (category == null) return true;
      if (category == '⚠') {
        final f = freshnessOf(i);
        return f == Freshness.soon || f == Freshness.expired || i.quantity <= 0;
      }
      return i.ingredient.category == category;
    }).toList()
      ..sort((a, b) {
        // Primero lo que requiere atención, luego por nombre.
        int weight(PantryItem p) {
          if (p.quantity <= 0) return 0;
          switch (freshnessOf(p)) {
            case Freshness.expired:
              return 1;
            case Freshness.soon:
              return 2;
            default:
              return 3;
          }
        }
        final w = weight(a).compareTo(weight(b));
        return w != 0 ? w : a.ingredient.name.compareTo(b.ingredient.name);
      });

    final grouped = <String, List<PantryItem>>{};
    for (final item in visible) {
      grouped.putIfAbsent(item.ingredient.category, () => []).add(item);
    }
    final groupKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _summary(items.length, expiring, out),
                  style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            children: [
              _catChip(null, 'Todo (${items.length})'),
              if (expiring + out > 0)
                _catChip('⚠', 'Atención (${expiring + out})', color: Colors.orange.shade800),
              for (final c in categories)
                _catChip(c, '$c (${items.where((i) => i.ingredient.category == c).length})'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
            children: [
              for (final cat in groupKeys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
                  child: Text(
                    cat,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                ...grouped[cat]!.map(_tile),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _summary(int total, int expiring, int out) {
    final parts = <String>[
      '$total ingrediente${total == 1 ? '' : 's'}',
      if (expiring > 0) '$expiring caduca${expiring == 1 ? '' : 'n'} pronto',
      if (out > 0) '$out agotado${out == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }

  Widget _catChip(String? value, String label, {Color? color}) {
    final selected = category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: color?.withValues(alpha: 0.2),
        onSelected: (_) => setState(() => category = selected ? null : value),
      ),
    );
  }

  Widget _tile(PantryItem item) {
    final freshness = freshnessOf(item);
    final out = item.quantity <= 0;
    final scheme = Theme.of(context).colorScheme;

    final Color dot;
    final String status;
    if (out) {
      dot = scheme.error;
      status = 'Se ha acabado · toca para reponer';
    } else {
      switch (freshness) {
        case Freshness.expired:
          dot = scheme.error;
          status = '${formatQuantity(item.quantity)} ${item.unit} · ${expiryText(item)}';
        case Freshness.soon:
          dot = Colors.orange.shade800;
          status = '${formatQuantity(item.quantity)} ${item.unit} · ${expiryText(item)}';
        case Freshness.ok:
          dot = const Color(0xFF2E7D32);
          status = '${formatQuantity(item.quantity)} ${item.unit} · ${expiryText(item)}';
        case Freshness.none:
          dot = ink.withValues(alpha: 0.25);
          status = '${formatQuantity(item.quantity)} ${item.unit}';
      }
    }
    final attention = out || freshness == Freshness.expired || freshness == Freshness.soon;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => _remove(item),
      child: ListTile(
        onTap: () => _edit(item),
        leading: Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        minLeadingWidth: 16,
        title: Text(
          item.ingredient.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          status,
          style: TextStyle(color: attention ? dot : ink.withValues(alpha: 0.6)),
        ),
        trailing: out
            ? TextButton.icon(
                onPressed: () => _toShopping(item),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Comprar'),
              )
            : Icon(Icons.chevron_right, color: ink.withValues(alpha: 0.3)),
      ),
    );
  }
}
