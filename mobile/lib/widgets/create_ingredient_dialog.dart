import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';

/// Por si la API no responde al pedir categorías.
const _fallbackCategories = <String>[
  'Lácteos',
  'Verduras',
  'Frutas',
  'Carnes',
  'Pescados',
  'Cereales',
  'Legumbres',
  'Especias',
  'Condimentos',
  'Otros',
];

/// Diálogo para dar de alta un ingrediente que no está en el catálogo.
/// Devuelve el ingrediente creado (o el existente si ya había uno igual).
Future<Ingredient?> showCreateIngredientDialog(
  BuildContext context, {
  required ApiClient api,
  String initialName = '',
}) {
  return showDialog<Ingredient>(
    context: context,
    builder: (_) => _CreateIngredientDialog(api: api, initialName: initialName),
  );
}

class _CreateIngredientDialog extends StatefulWidget {
  const _CreateIngredientDialog({required this.api, required this.initialName});

  final ApiClient api;
  final String initialName;

  @override
  State<_CreateIngredientDialog> createState() => _CreateIngredientDialogState();
}

class _CreateIngredientDialogState extends State<_CreateIngredientDialog> {
  late final TextEditingController name;
  List<String> categories = _fallbackCategories;
  String category = 'Otros';
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: _capitalize(widget.initialName.trim()));
    widget.api.ingredientCategories().then((list) {
      if (!mounted || list.isEmpty) return;
      setState(() {
        categories = list;
        if (!categories.contains(category)) category = categories.last;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _submit() async {
    final value = name.text.trim();
    if (value.length < 2) {
      setState(() => error = 'Escribe el nombre del ingrediente');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final created = await widget.api.createIngredient(value, category: category);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = ApiClient.describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo ingrediente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No está en el catálogo. Lo añadimos para ti y para el resto de usuarios.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nombre', errorText: error),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (c) => setState(() => category = c ?? category),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _submit,
          child: Text(saving ? 'Creando…' : 'Crear'),
        ),
      ],
    );
  }
}
