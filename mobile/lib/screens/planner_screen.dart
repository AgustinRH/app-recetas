import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/quantity_dialog.dart';

const _dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late DateTime monday;
  WeekPlan? plan;
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    monday = _monday(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await ref.read(apiProvider).planner(_ymd(monday));
      if (!mounted) return;
      setState(() {
        plan = next;
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

  Future<void> _assign(int day, String meal, String? recipeId) async {
    setState(() => saving = true);
    try {
      final next = await ref.read(apiProvider).setPlanSlot(
            weekStart: _ymd(monday),
            dayIndex: day,
            meal: meal,
            recipeId: recipeId,
          );
      if (!mounted) return;
      setState(() => plan = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.describeError(e))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pick(int day, String meal) async {
    if (saving) return;
    final current = plan?.recipeAt(day, meal);
    List<RecipeCard> saved = [];
    try {
      saved = await ref.read(apiProvider).savedRecipes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.describeError(e))),
      );
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecipePicker(
        recipes: saved,
        selectedId: current?.id,
        canClear: current != null,
      ),
    );
    if (!mounted || picked == null) return;
    await _assign(day, meal, picked == '' ? null : picked);
  }

  Future<void> _toShopping() async {
    final gaps = plan?.gaps ?? const <PlanGap>[];
    if (gaps.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final n = await ref.read(apiProvider).plannerToShopping(_ymd(monday));
      ref.invalidate(shoppingProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'No falta nada para esta semana'
                : n == 1
                    ? '1 ingrediente en la lista de la compra'
                    : '$n ingredientes en la lista de la compra',
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
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gaps = plan?.gaps ?? const <PlanGap>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Plan de la semana')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: gaps.isEmpty || saving ? null : _toShopping,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(
              gaps.isEmpty ? 'No falta nada' : 'Añadir ${gaps.length} a la compra',
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _weekBar(),
          Expanded(child: _body(gaps)),
        ],
      ),
    );
  }

  Widget _weekBar() {
    final end = monday.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: saving
                ? null
                : () {
                    setState(() => monday = monday.subtract(const Duration(days: 7)));
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '${monday.day} ${_months[monday.month - 1]} – ${end.day} ${_months[end.month - 1]}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            onPressed: saving
                ? null
                : () {
                    setState(() => monday = monday.add(const Duration(days: 7)));
                    _load();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _body(List<PlanGap> gaps) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Elige comida y cena. Abajo verás lo que te falta para toda la semana, restando la despensa una sola vez.',
          style: TextStyle(color: ink.withValues(alpha: 0.65), height: 1.35),
        ),
        const SizedBox(height: 12),
        for (var day = 0; day < 7; day++) _dayCard(day),
        const SizedBox(height: 8),
        _gapsCard(gaps),
      ],
    );
  }

  Widget _dayCard(int day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dayNames[day], style: const TextStyle(fontWeight: FontWeight.w800)),
              _slotTile(day, 'comida', 'Comida'),
              _slotTile(day, 'cena', 'Cena'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotTile(int day, String meal, String label) {
    final recipe = plan?.recipeAt(day, meal);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: ink.withValues(alpha: 0.55), fontSize: 12)),
      subtitle: Text(
        recipe?.title ?? 'Elegir receta',
        style: TextStyle(
          color: recipe == null ? terracotta : ink,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      trailing: Icon(recipe == null ? Icons.add : Icons.edit_outlined, color: terracotta),
      onTap: saving ? null : () => _pick(day, meal),
    );
  }

  Widget _gapsCard(List<PlanGap> gaps) {
    final hasMeals = plan?.slots.isNotEmpty ?? false;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gaps.isEmpty ? 'Compra de la semana' : 'Te faltan ${gaps.length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (!hasMeals)
              Text(
                'Asigna alguna receta para ver qué comprar.',
                style: TextStyle(color: ink.withValues(alpha: 0.65)),
              )
            else if (gaps.isEmpty)
              Text(
                'Con lo que tienes en la despensa llegas a todas las recetas de esta semana.',
                style: TextStyle(color: ink.withValues(alpha: 0.65)),
              )
            else
              ...gaps.map(
                (gap) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(gap.name)),
                      Text(
                        '${formatQuantity(gap.quantity)} ${gap.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({
    required this.recipes,
    required this.selectedId,
    required this.canClear,
  });

  final List<RecipeCard> recipes;
  final String? selectedId;
  final bool canClear;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.trim().toLowerCase();
    final shown = widget.recipes
        .where((r) => q.isEmpty || r.title.toLowerCase().contains(q))
        .toList();
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: search,
                decoration: const InputDecoration(
                  hintText: 'Buscar en guardadas',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (widget.canClear)
              ListTile(
                leading: const Icon(Icons.close, color: terracotta),
                title: const Text('Quitar de este hueco'),
                onTap: () => Navigator.pop(context, ''),
              ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.recipes.isEmpty
                              ? 'Guarda recetas desde su ficha y aparecerán aquí.'
                              : 'Ninguna guardada coincide.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final recipe = shown[i];
                        final selected = recipe.id == widget.selectedId;
                        return ListTile(
                          title: Text(recipe.title),
                          subtitle: Text('${recipe.prepMinutes} min · ${recipe.cuisine}'),
                          trailing: selected ? const Icon(Icons.check, color: terracotta) : null,
                          onTap: () => Navigator.pop(context, recipe.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _monday(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _ymd(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
