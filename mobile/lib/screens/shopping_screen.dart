import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/create_ingredient_dialog.dart';
import '../widgets/quantity_dialog.dart';

/// Pantalla completa (ruta `/shopping`).
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de la compra')),
      body: const ShoppingListView(),
    );
  }
}

/// Cuerpo de la lista de la compra; se embebe también en la pestaña de la
/// despensa.
class ShoppingListView extends ConsumerStatefulWidget {
  const ShoppingListView({super.key});

  @override
  ConsumerState<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends ConsumerState<ShoppingListView> {
  final query = TextEditingController();
  List<Ingredient> suggestions = [];
  bool searched = false;
  bool busy = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void _toast(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
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

  Future<void> _add(Ingredient ingredient) async {
    final result = await showQuantityDialog(
      context,
      title: ingredient.name,
      confirmLabel: 'Añadir a la lista',
    );
    if (result == null) return;
    try {
      await ref.read(apiProvider).addShopping(
            ingredient.id,
            quantity: result.quantity,
            unit: result.unit,
          );
      query.clear();
      if (mounted) {
        setState(() {
          suggestions = [];
          searched = false;
        });
      }
      ref.invalidate(shoppingProvider);
    } catch (e) {
      if (mounted) _toast('No se pudo añadir: ${ApiClient.describeError(e)}');
    }
  }

  Future<void> _createAndAdd() async {
    final created = await showCreateIngredientDialog(
      context,
      api: ref.read(apiProvider),
      initialName: query.text,
    );
    if (created == null || !mounted) return;
    await _add(created);
  }

  Future<void> _toggle(ShoppingItem item, bool checked) async {
    try {
      await ref.read(apiProvider).updateShopping(item.id, checked: checked);
      ref.invalidate(shoppingProvider);
    } catch (e) {
      if (mounted) _toast(ApiClient.describeError(e));
    }
  }

  Future<void> _edit(ShoppingItem item) async {
    final result = await showQuantityDialog(
      context,
      title: item.ingredient.name,
      initialQuantity: item.quantity,
      initialUnit: item.unit,
    );
    if (result == null) return;
    try {
      await ref.read(apiProvider).updateShopping(
            item.id,
            quantity: result.quantity,
            unit: result.unit,
          );
      ref.invalidate(shoppingProvider);
    } catch (e) {
      if (mounted) _toast(ApiClient.describeError(e));
    }
  }

  Future<void> _remove(ShoppingItem item) async {
    try {
      await ref.read(apiProvider).removeShopping(item.id);
      ref.invalidate(shoppingProvider);
    } catch (e) {
      if (mounted) _toast(ApiClient.describeError(e));
    }
  }

  Future<void> _checkout() async {
    setState(() => busy = true);
    try {
      final moved = await ref.read(apiProvider).checkoutShopping();
      ref.invalidate(shoppingProvider);
      ref.invalidate(pantryProvider);
      ref.invalidate(feedProvider);
      if (mounted) {
        _toast(
          moved == 1
              ? '1 ingrediente añadido a la despensa'
              : '$moved ingredientes añadidos a la despensa',
        );
      }
    } catch (e) {
      if (mounted) _toast(ApiClient.describeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar la lista'),
        content: const Text('Se quitarán todas las líneas, también las no marcadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vaciar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).clearShopping();
      ref.invalidate(shoppingProvider);
    } catch (e) {
      if (mounted) _toast(ApiClient.describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(shoppingProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: query,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.add_shopping_cart),
              hintText: 'Añadir a la lista…',
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
                      onPressed: () => _add(i),
                    ),
                  ),
                if (!_exactHit)
                  ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text('Crear «${query.text.trim()}»'),
                    onPressed: _createAndAdd,
                  ),
              ],
            ),
          ),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (items) => _body(items),
          ),
        ),
      ],
    );
  }

  Widget _body(List<ShoppingItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛒', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                'La lista está vacía',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Añade ingredientes aquí o, desde una receta, pulsa «Añadir lo que falta».',
                textAlign: TextAlign.center,
                style: TextStyle(color: ink.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }
    final pending = items.where((i) => !i.checked).toList();
    final checked = items.where((i) => i.checked).toList();
    final grouped = <String, List<ShoppingItem>>{};
    for (final i in pending) {
      grouped.putIfAbsent(i.ingredient.category, () => []).add(i);
    }
    final categories = grouped.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${pending.length} por comprar · ${checked.length} en el carrito',
                  style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Vaciar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            children: [
              for (final cat in categories) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
                  child: Text(
                    cat,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                ...grouped[cat]!.map(_tile),
              ],
              if (checked.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 2),
                  child: Text(
                    'En el carrito',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: ink.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                ...checked.map(_tile),
              ],
            ],
          ),
        ),
        if (checked.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _checkout,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.kitchen_outlined),
                  label: Text(
                    'Pasar ${checked.length} a la despensa',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(ShoppingItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => _remove(item),
      child: CheckboxListTile(
        value: item.checked,
        onChanged: (v) => _toggle(item, v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          item.ingredient.name,
          style: TextStyle(
            decoration: item.checked ? TextDecoration.lineThrough : null,
            color: item.checked ? ink.withValues(alpha: 0.5) : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text('${formatQuantity(item.quantity)} ${item.unit}'),
        secondary: IconButton(
          tooltip: 'Cambiar cantidad',
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () => _edit(item),
        ),
      ),
    );
  }
}
