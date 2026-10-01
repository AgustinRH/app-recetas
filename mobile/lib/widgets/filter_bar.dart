import 'package:flutter/material.dart';

import '../models.dart';

const kDietFilters = ['vegetariana', 'vegana', 'sin gluten', 'keto'];
const kMinuteFilters = [10, 20, 30, 45, 60];

/// Centinela para la opción "Cualquiera" de los menús.
const _clear = Object();

/// Fila horizontal de chips para filtrar recetas por tiempo, cocina y dieta.
///
/// Es la misma en el feed y en la búsqueda; el estado lo gestiona quien la usa.
class RecipeFilterBar extends StatelessWidget {
  const RecipeFilterBar({
    super.key,
    required this.filters,
    required this.cuisines,
    required this.onChanged,
    this.leading = const [],
  });

  final RecipeFilters filters;
  final List<String> cuisines;
  final ValueChanged<RecipeFilters> onChanged;

  /// Chips extra al principio (por ejemplo el orden del feed).
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          ...leading.map((w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: w,
              )),
          if (!filters.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.close, size: 16),
                label: const Text('Limpiar'),
                onPressed: () => onChanged(const RecipeFilters()),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _menuChip<int>(
              context,
              icon: Icons.schedule,
              label: filters.maxMinutes == null
                  ? 'Tiempo'
                  : '≤ ${filters.maxMinutes} min',
              selected: filters.maxMinutes != null,
              values: kMinuteFilters,
              current: filters.maxMinutes,
              display: (m) => 'Hasta $m min',
              onSelect: (m) => onChanged(
                m == null
                    ? filters.copyWith(clearMinutes: true)
                    : filters.copyWith(maxMinutes: m),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _menuChip<String>(
              context,
              icon: Icons.public,
              label: filters.cuisine ?? 'Cocina',
              selected: filters.cuisine != null,
              values: cuisines,
              current: filters.cuisine,
              display: (c) => c,
              onSelect: (c) => onChanged(
                c == null
                    ? filters.copyWith(clearCuisine: true)
                    : filters.copyWith(cuisine: c),
              ),
            ),
          ),
          ...kDietFilters.map(
            (d) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(d),
                selected: filters.diet == d,
                onSelected: (v) => onChanged(
                  v ? filters.copyWith(diet: d) : filters.copyWith(clearDiet: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuChip<T>(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required List<T> values,
    required T? current,
    required String Function(T) display,
    required ValueChanged<T?> onSelect,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // PopupMenuButton trata un valor `null` como "cancelado", así que para
    // "Cualquiera" usamos un centinela.
    return PopupMenuButton<Object>(
      tooltip: label,
      onSelected: (v) => onSelect(v == _clear ? null : v as T),
      itemBuilder: (_) => [
        if (selected)
          const PopupMenuItem<Object>(value: _clear, child: Text('Cualquiera')),
        ...values.map(
          (v) => PopupMenuItem<Object>(
            value: v,
            child: Row(
              children: [
                if (v == current) const Icon(Icons.check, size: 16),
                if (v == current) const SizedBox(width: 6),
                Text(display(v)),
              ],
            ),
          ),
        ),
      ],
      // Un chip "a mano": el PopupMenuButton captura el toque, así que un
      // FilterChip real saldría deshabilitado y gris.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.secondaryContainer
              : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.transparent : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
