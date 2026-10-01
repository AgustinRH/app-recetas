import 'package:flutter/material.dart';

/// Unidades que se ofrecen en el selector. Deben coincidir con las que el
/// backend sabe convertir (`compute-match.ts`); las que no están tabuladas
/// allí (diente, rebanada…) solo se comparan entre sí.
const kUnits = <String>[
  'ud',
  'g',
  'kg',
  'ml',
  'l',
  'cdita',
  'cda',
  'taza',
  'diente',
  'rebanada',
  'loncha',
  'manojo',
  'hoja',
  'pizca',
];

/// [expiresAt] solo se usa cuando el diálogo se abre con `withExpiry: true`.
typedef Quantity = ({double quantity, String unit, DateTime? expiresAt});

/// "2", "0.5", "1.5" — sin ".0" cuando es entero.
String formatQuantity(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  return q.toStringAsFixed(q * 10 == (q * 10).roundToDouble() ? 1 : 2);
}

/// Pide cantidad + unidad. Devuelve null si el usuario cancela.
Future<Quantity?> showQuantityDialog(
  BuildContext context, {
  required String title,
  double initialQuantity = 1,
  String initialUnit = 'ud',
  String confirmLabel = 'Guardar',
  bool withExpiry = false,
  DateTime? initialExpiry,
}) {
  return showDialog<Quantity>(
    context: context,
    builder: (_) => _QuantityDialog(
      title: title,
      initialQuantity: initialQuantity,
      initialUnit: initialUnit,
      confirmLabel: confirmLabel,
      withExpiry: withExpiry,
      initialExpiry: initialExpiry,
    ),
  );
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.title,
    required this.initialQuantity,
    required this.initialUnit,
    required this.confirmLabel,
    required this.withExpiry,
    this.initialExpiry,
  });

  final String title;
  final double initialQuantity;
  final String initialUnit;
  final String confirmLabel;
  final bool withExpiry;
  final DateTime? initialExpiry;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController qty;
  late String unit;
  DateTime? expiresAt;
  String? error;

  @override
  void initState() {
    super.initState();
    qty = TextEditingController(text: formatQuantity(widget.initialQuantity));
    // Si la unidad guardada no está en la lista (dato antiguo), la añadimos.
    unit = widget.initialUnit;
    expiresAt = widget.initialExpiry;
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'Fecha de caducidad',
    );
    if (picked != null) setState(() => expiresAt = picked);
  }

  String _expiryLabel() {
    final d = expiresAt;
    if (d == null) return 'Sin fecha de caducidad';
    final days = DateTime(d.year, d.month, d.day)
        .difference(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0))
        .inDays;
    final date = '${d.day}/${d.month}/${d.year}';
    if (days < 0) return 'Caducó el $date';
    if (days == 0) return 'Caduca hoy ($date)';
    if (days == 1) return 'Caduca mañana ($date)';
    return 'Caduca en $days días ($date)';
  }

  @override
  void dispose() {
    qty.dispose();
    super.dispose();
  }

  List<String> get _units =>
      kUnits.contains(unit) ? kUnits : [unit, ...kUnits];

  void _bump(double delta) {
    final current = double.tryParse(qty.text.replaceAll(',', '.')) ?? 0;
    final next = (current + delta).clamp(0, 100000).toDouble();
    setState(() {
      qty.text = formatQuantity(next);
      error = null;
    });
  }

  void _submit() {
    final value = double.tryParse(qty.text.trim().replaceAll(',', '.'));
    if (value == null || value < 0) {
      setState(() => error = 'Pon un número (0 si se ha acabado)');
      return;
    }
    Navigator.of(context).pop((quantity: value, unit: unit, expiresAt: expiresAt));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton.outlined(
                onPressed: () => _bump(-1),
                icon: const Icon(Icons.remove),
                tooltip: 'Menos',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: qty,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    errorText: error,
                  ),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () => _bump(1),
                icon: const Icon(Icons.add),
                tooltip: 'Más',
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: unit,
            decoration: const InputDecoration(labelText: 'Unidad'),
            items: _units
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (u) => setState(() => unit = u ?? unit),
          ),
          if (widget.withExpiry) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.event_outlined),
              title: Text(_expiryLabel()),
              onTap: _pickExpiry,
              trailing: expiresAt == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: 'Quitar fecha',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => expiresAt = null),
                    ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
