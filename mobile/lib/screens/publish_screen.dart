import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/create_ingredient_dialog.dart';
import '../widgets/quantity_dialog.dart';

const _cuisines = <String>[
  'Mediterránea',
  'Española',
  'Italiana',
  'Mexicana',
  'Asiática',
  'Internacional',
  'Otra',
];

const _dietTags = <String>['vegetariana', 'vegana', 'sin gluten', 'keto'];

/// Ingrediente elegido para la receta con la cantidad que pide.
class _Line {
  _Line(this.ingredient, {this.quantity = 1, this.unit = 'ud'});

  final Ingredient ingredient;
  double quantity;
  String unit;
  bool optional = false;
}

/// Un paso con su controlador de texto (para poder editarlo en sitio).
class _Step {
  _Step([String text = '']) : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final focus = FocusNode();

  String get text => controller.text.trim();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final prep = TextEditingController(text: '20');
  final calories = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();
  final ingredientQuery = TextEditingController();

  String cuisine = _cuisines.first;
  String difficulty = 'fácil';
  int servings = 2;
  final diets = <String>{};
  final selected = <_Line>[];
  final steps = <_Step>[_Step()];
  List<Ingredient> hits = [];
  bool searching = false;
  Timer? _debounce;

  XFile? photo;
  Uint8List? photoBytes;
  bool saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    title.dispose();
    description.dispose();
    prep.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    ingredientQuery.dispose();
    for (final s in steps) {
      s.dispose();
    }
    super.dispose();
  }

  // ───────────────────────── helpers ─────────────────────────

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _stepTexts() =>
      steps.map((s) => s.text).where((t) => t.isNotEmpty).toList();

  String? _validate() {
    if (title.text.trim().isEmpty) return 'Ponle un título a la receta.';
    final minutes = int.tryParse(prep.text.trim());
    if (minutes == null || minutes < 1) {
      return 'Los minutos tienen que ser un número mayor que 0.';
    }
    if (calories.text.trim().isNotEmpty &&
        double.tryParse(calories.text.trim().replaceAll(',', '.')) == null) {
      return 'Las calorías tienen que ser un número (o déjalo vacío).';
    }
    for (final c in [protein, carbs, fat]) {
      if (c.text.trim().isNotEmpty &&
          double.tryParse(c.text.trim().replaceAll(',', '.')) == null) {
        return 'Los macros tienen que ser números (o déjalos vacíos).';
      }
    }
    if (selected.isEmpty) {
      return 'Añade al menos un ingrediente: busca por nombre y toca la sugerencia.';
    }
    if (_stepTexts().isEmpty) return 'Escribe al menos un paso.';
    return null;
  }

  // ───────────────────────── ingredientes ─────────────────────────

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        hits = [];
        searching = false;
      });
      return;
    }
    setState(() => searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final list = await ref.read(apiProvider).ingredients(q: q.trim());
        if (!mounted || ingredientQuery.text.trim() != q.trim()) return;
        setState(() {
          hits = list.where((i) => !selected.any((s) => s.ingredient.id == i.id)).toList();
          searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => searching = false);
      }
    });
  }

  Future<void> _addIngredient(Ingredient i) async {
    final result = await showQuantityDialog(
      context,
      title: '${i.name}: ¿cuánto lleva?',
      confirmLabel: 'Añadir',
    );
    if (result == null || !mounted) return;
    setState(() {
      selected.add(_Line(i, quantity: result.quantity, unit: result.unit));
      hits = [];
      ingredientQuery.clear();
    });
  }

  bool get _exactHit {
    final q = ingredientQuery.text.trim().toLowerCase();
    return hits.any((i) => i.name.toLowerCase() == q) ||
        selected.any((l) => l.ingredient.name.toLowerCase() == q);
  }

  Future<void> _createIngredient() async {
    final created = await showCreateIngredientDialog(
      context,
      api: ref.read(apiProvider),
      initialName: ingredientQuery.text,
    );
    if (created == null || !mounted) return;
    if (selected.any((l) => l.ingredient.id == created.id)) {
      _toast('${created.name} ya está en la receta.');
      return;
    }
    await _addIngredient(created);
  }

  Future<void> _editLine(_Line line) async {
    final result = await showQuantityDialog(
      context,
      title: line.ingredient.name,
      initialQuantity: line.quantity,
      initialUnit: line.unit,
    );
    if (result == null || !mounted) return;
    setState(() {
      line
        ..quantity = result.quantity
        ..unit = result.unit;
    });
  }

  // ───────────────────────── pasos ─────────────────────────

  void _addStep() {
    final step = _Step();
    setState(() => steps.add(step));
    // Enfocar el nuevo paso en el siguiente frame, cuando ya esté pintado.
    WidgetsBinding.instance.addPostFrameCallback((_) => step.focus.requestFocus());
  }

  void _removeStep(int index) {
    final step = steps[index];
    setState(() {
      steps.removeAt(index);
      if (steps.isEmpty) steps.add(_Step()); // siempre queda uno para escribir
    });
    // Liberar después del frame: el TextField aún puede estar montado.
    WidgetsBinding.instance.addPostFrameCallback((_) => step.dispose());
  }

  void _moveStep(int from, int to) {
    setState(() {
      if (to > from) to -= 1;
      final step = steps.removeAt(from);
      steps.insert(to, step);
    });
  }

  // ───────────────────────── foto ─────────────────────────

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      photo = file;
      photoBytes = bytes;
    });
  }

  // ───────────────────────── publicar ─────────────────────────

  Future<void> _publish() async {
    final problem = _validate();
    if (problem != null) {
      _toast(problem);
      return;
    }
    setState(() => saving = true);
    final api = ref.read(apiProvider);
    try {
      double? parseNum(TextEditingController c) {
        final t = c.text.trim();
        return t.isEmpty ? null : double.parse(t.replaceAll(',', '.'));
      }
      final created = await api.createRecipe({
        'title': title.text.trim(),
        'description': description.text.trim(),
        'prepMinutes': int.parse(prep.text.trim()),
        'cuisine': cuisine,
        'dietTags': diets.toList(),
        'servings': servings,
        'difficulty': difficulty,
        if (parseNum(calories) != null) 'calories': parseNum(calories),
        if (parseNum(protein) != null) 'protein': parseNum(protein),
        if (parseNum(carbs) != null) 'carbs': parseNum(carbs),
        if (parseNum(fat) != null) 'fat': parseNum(fat),
        'ingredients': selected
            .map((l) => {
                  'ingredientId': l.ingredient.id,
                  'quantity': l.quantity,
                  'unit': l.unit,
                  'optional': l.optional,
                })
            .toList(),
        'steps': _stepTexts(),
      });
      if (photoBytes != null) {
        try {
          await api.uploadPhoto(
            created.card.id,
            photoBytes!,
            filename: (photo?.name.isNotEmpty ?? false) ? photo!.name : 'photo.jpg',
            mimeType: photo?.mimeType,
          );
        } catch (e) {
          if (mounted) {
            _toast('Receta publicada, pero la foto falló: ${ApiClient.describeError(e)}');
          }
        }
      }
      ref.invalidate(feedProvider);
      if (mounted) context.go('/recipe/${created.card.id}');
    } catch (e) {
      if (mounted) _toast('No se pudo publicar: ${ApiClient.describeError(e)}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar receta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section('Lo básico', [
            TextField(
              controller: title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Un par de líneas sobre el plato',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: prep,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutos *',
                      suffixText: 'min',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Raciones',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove),
                          onPressed: servings > 1
                              ? () => setState(() => servings--)
                              : null,
                        ),
                        Text(
                          '$servings',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add),
                          onPressed: servings < 50
                              ? () => setState(() => servings++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'fácil',
                  label: Text('Fácil'),
                  icon: Icon(Icons.eco_outlined),
                ),
                ButtonSegment(
                  value: 'media',
                  label: Text('Media'),
                  icon: Icon(Icons.local_fire_department_outlined),
                ),
                ButtonSegment(
                  value: 'difícil',
                  label: Text('Difícil'),
                  icon: Icon(Icons.whatshot),
                ),
              ],
              selected: {difficulty},
              onSelectionChanged: (s) => setState(() => difficulty = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: cuisine,
              decoration: const InputDecoration(labelText: 'Tipo de cocina'),
              items: _cuisines
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (c) => setState(() => cuisine = c ?? cuisine),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _dietTags
                  .map(
                    (tag) => FilterChip(
                      label: Text(tag),
                      selected: diets.contains(tag),
                      onSelected: (on) => setState(() {
                        on ? diets.add(tag) : diets.remove(tag);
                      }),
                    ),
                  )
                  .toList(),
            ),
          ]),
          _section('Nutrición por ración (opcional)', [
            Row(
              children: [
                Expanded(child: _numField(calories, 'Calorías', 'kcal')),
                const SizedBox(width: 8),
                Expanded(child: _numField(protein, 'Proteína', 'g')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numField(carbs, 'Hidratos', 'g')),
                const SizedBox(width: 8),
                Expanded(child: _numField(fat, 'Grasas', 'g')),
              ],
            ),
          ]),
          _section('Foto', [_photoPicker()]),
          _section('Ingredientes *', [
            TextField(
              controller: ingredientQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Buscar en el catálogo',
                hintText: 'p. ej. ajo, huevos, arroz…',
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ingredientQuery.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              ingredientQuery.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
              ),
              onChanged: _onQueryChanged,
            ),
            if (!searching && ingredientQuery.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              if (hits.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'No está en el catálogo. Puedes crearlo:',
                    style: TextStyle(color: ink.withValues(alpha: 0.6)),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final i in hits)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(i.name),
                      onPressed: () => _addIngredient(i),
                    ),
                  if (!_exactHit)
                    ActionChip(
                      avatar: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text('Crear «${ingredientQuery.text.trim()}»'),
                      onPressed: _createIngredient,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (selected.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Busca un ingrediente y toca la sugerencia; te preguntará la cantidad.',
                  style: TextStyle(color: ink.withValues(alpha: 0.6)),
                ),
              )
            else
              ...selected.map(_ingredientRow),
          ]),
          _section('Pasos *', [
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: steps.length,
              // onReorderItem es de Flutter 3.41+; onReorder sigue funcionando.
              // ignore: deprecated_member_use
              onReorder: _moveStep,
              itemBuilder: (context, index) => _stepRow(index, key: ValueKey(steps[index])),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: const Text('Añadir paso'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: saving ? null : _publish,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(saving ? 'Publicando…' : 'Publicar receta'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, String suffix) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  Widget _section(String heading, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              heading,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _photoPicker() {
    final preview = photoBytes;
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: terracotta.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: terracotta.withValues(alpha: 0.3)),
        ),
        child: preview == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: terracotta, size: 32),
                  const SizedBox(height: 8),
                  Text('Añadir foto', style: TextStyle(color: ink.withValues(alpha: 0.8))),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(preview, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Row(
                      children: [
                        _photoAction(Icons.edit, 'Cambiar', _pickPhoto),
                        const SizedBox(width: 6),
                        _photoAction(Icons.delete_outline, 'Quitar', () {
                          setState(() {
                            photo = null;
                            photoBytes = null;
                          });
                        }),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _photoAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _ingredientRow(_Line line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: ListTile(
        onTap: () => _editLine(line),
        title: Text(line.ingredient.name),
        subtitle: Text(
          '${formatQuantity(line.quantity)} ${line.unit}'
          '${line.optional ? ' · opcional' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: line.optional ? 'Marcar como necesario' : 'Marcar como opcional',
              child: IconButton(
                icon: Icon(
                  line.optional ? Icons.star_border : Icons.star,
                  color: line.optional ? Colors.grey : terracotta,
                ),
                onPressed: () => setState(() => line.optional = !line.optional),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Quitar',
              onPressed: () => setState(() => selected.remove(line)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(int index, {required Key key}) {
    final step = steps[index];
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: terracotta,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: step.controller,
              focusNode: step.focus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: index == 0
                    ? 'p. ej. Pela y corta las patatas'
                    : 'Paso ${index + 1}',
                isDense: true,
              ),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(top: 10, left: 4),
              child: Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Quitar paso',
            onPressed: () => _removeStep(index),
          ),
        ],
      ),
    );
  }
}
