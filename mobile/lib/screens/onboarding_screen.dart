import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

const dietOptions = ['vegana', 'vegetariana', 'keto', 'sin gluten'];
const allergyOptions = ['gluten', 'lactosa', 'frutos secos', 'marisco', 'huevo'];

/// Básicos que casi todo el mundo tiene; se ofrecen en el segundo paso para
/// que la despensa no empiece vacía.
const _staples = <String>[
  'Sal',
  'Aceite de oliva',
  'Pimienta',
  'Ajo',
  'Cebolla',
  'Huevos',
  'Leche',
  'Arroz',
  'Pasta',
  'Harina',
  'Azúcar',
  'Tomate',
  'Patata',
  'Pan',
  'Mantequilla',
  'Queso',
  'Limón',
  'Zanahoria',
  'Pollo',
  'Atún',
  'Lentejas',
  'Garbanzos',
  'Vinagre',
  'Pimentón',
  'Orégano',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final name = TextEditingController();
  final diets = <String>{};
  final allergies = <String>{};
  final pages = PageController();

  int page = 0;
  bool saving = false;

  /// Catálogo cargado para el paso de despensa, por nombre.
  Map<String, Ingredient> catalog = {};
  final chosen = <String>{};
  bool loadingCatalog = true;

  /// Si el usuario ya tenía nombre al entrar, es edición de preferencias:
  /// un solo paso. Se decide una vez para que no cambie al guardar.
  late final bool editing;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    editing = !(profile?.needsOnboarding ?? true);
    if (profile != null && !profile.needsOnboarding) {
      name.text = profile.displayName;
      diets.addAll(profile.diets);
      allergies.addAll(profile.allergies);
    } else {
      // Sugerimos un nombre a partir del email; el usuario puede cambiarlo.
      final local = profile?.email?.split('@').first ?? '';
      if (local.isNotEmpty) {
        name.text = local[0].toUpperCase() + local.substring(1);
      }
    }
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final all = await ref.read(apiProvider).ingredients(limit: 500);
      if (!mounted) return;
      setState(() {
        catalog = {for (final i in all) i.name.toLowerCase(): i};
        loadingCatalog = false;
        // Preseleccionamos lo más básico.
        for (final n in ['Sal', 'Aceite de oliva', 'Ajo', 'Cebolla', 'Huevos']) {
          if (catalog.containsKey(n.toLowerCase())) chosen.add(n);
        }
      });
    } catch (_) {
      if (mounted) setState(() => loadingCatalog = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    pages.dispose();
    super.dispose();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _savePrefs() async {
    final n = name.text.trim();
    if (n.isEmpty) {
      _toast('Escribe un nombre');
      return;
    }
    setState(() => saving = true);
    // Evita que el router nos saque de /onboarding al dejar de "necesitarlo".
    if (!editing) ref.read(onboardingPendingProvider.notifier).state = true;
    try {
      await ref.read(authProvider.notifier).updateProfile(
            displayName: n,
            diets: diets.toList(),
            allergies: allergies.toList(),
          );
      if (!mounted) return;
      if (editing) {
        context.pop();
      } else {
        setState(() => page = 1);
        pages.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) _toast('No se pudo guardar: ${ApiClient.describeError(e)}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _savePantry() async {
    setState(() => saving = true);
    final api = ref.read(apiProvider);
    var added = 0;
    for (final n in chosen) {
      final ing = catalog[n.toLowerCase()];
      if (ing == null) continue;
      try {
        await api.addPantry(ing.id, quantity: _defaultQty(n), unit: _defaultUnit(n));
        added++;
      } catch (_) {}
    }
    ref.invalidate(pantryProvider);
    ref.invalidate(feedProvider);
    if (!mounted) return;
    setState(() => saving = false);
    if (added > 0) _toast('$added ingredientes añadidos a tu despensa');
    ref.read(onboardingPendingProvider.notifier).state = false;
    if (!mounted) return;
    final back = ref.read(returnToProvider);
    ref.read(returnToProvider.notifier).state = null;
    context.go(back ?? '/feed');
  }

  double _defaultQty(String n) {
    switch (n) {
      case 'Sal':
      case 'Azúcar':
      case 'Harina':
      case 'Arroz':
      case 'Pasta':
      case 'Lentejas':
      case 'Garbanzos':
        return 500;
      case 'Aceite de oliva':
      case 'Leche':
        return 1;
      case 'Huevos':
        return 6;
      case 'Pimienta':
      case 'Pimentón':
      case 'Orégano':
        return 50;
      case 'Vinagre':
        return 250;
      case 'Mantequilla':
      case 'Queso':
        return 200;
      case 'Pollo':
        return 500;
      case 'Atún':
        return 2;
      default:
        return 2;
    }
  }

  String _defaultUnit(String n) {
    switch (n) {
      case 'Sal':
      case 'Azúcar':
      case 'Harina':
      case 'Arroz':
      case 'Pasta':
      case 'Lentejas':
      case 'Garbanzos':
      case 'Pimienta':
      case 'Pimentón':
      case 'Orégano':
      case 'Mantequilla':
      case 'Queso':
      case 'Pollo':
        return 'g';
      case 'Aceite de oliva':
      case 'Leche':
        return 'l';
      case 'Vinagre':
        return 'ml';
      default:
        return 'ud';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = editing;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Preferencias' : (page == 0 ? 'Tu cocina' : 'Tu despensa')),
        leading: !isEdit && page == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => page = 0);
                  pages.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              )
            : null,
      ),
      body: Column(
        children: [
          if (!isEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  _dot(0),
                  const SizedBox(width: 6),
                  _dot(1),
                  const SizedBox(width: 10),
                  Text(
                    'Paso ${page + 1} de 2',
                    style: TextStyle(color: ink.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PageView(
              controller: pages,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _prefsPage(isEdit),
                if (!isEdit) _pantryPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int i) => Container(
        width: 22,
        height: 6,
        decoration: BoxDecoration(
          color: i <= page ? terracotta : terracotta.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
        ),
      );

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: TextStyle(color: ink.withValues(alpha: 0.6))),
      );

  Widget _prefsPage(bool isEdit) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!isEdit) ...[
          const Text(
            '¡Bienvenido a DishToday! 🍳',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          _hint('Cuéntanos un poco de ti para ajustar las recetas que te sugerimos.'),
          const SizedBox(height: 12),
        ],
        _heading('¿Cómo te llamamos?'),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre o apodo'),
        ),
        const SizedBox(height: 24),
        _heading('Dieta'),
        _hint('Marcaremos las recetas que encajan y podrás filtrar por ellas.'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: dietOptions
              .map(
                (d) => FilterChip(
                  label: Text(d),
                  selected: diets.contains(d),
                  onSelected: (v) => setState(() => v ? diets.add(d) : diets.remove(d)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        _heading('Alergias e intolerancias'),
        _hint('Lo tendremos en cuenta en las recomendaciones.'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: allergyOptions
              .map(
                (d) => FilterChip(
                  label: Text(d),
                  selected: allergies.contains(d),
                  onSelected: (v) =>
                      setState(() => v ? allergies.add(d) : allergies.remove(d)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: saving ? null : _savePrefs,
          child: Text(isEdit ? 'Guardar' : 'Siguiente'),
        ),
      ],
    );
  }

  Widget _pantryPage() {
    final available = _staples.where((n) => catalog.containsKey(n.toLowerCase())).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '¿Qué tienes en casa?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        _hint(
          'Marca los básicos que ya tienes. Después podrás ajustar cantidades y '
          'añadir cualquier otro ingrediente desde la pestaña Despensa.',
        ),
        const SizedBox(height: 8),
        if (loadingCatalog)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (available.isEmpty)
          _hint('No se pudo cargar el catálogo; puedes añadir ingredientes luego.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: available
                .map(
                  (n) => FilterChip(
                    label: Text(n),
                    selected: chosen.contains(n),
                    onSelected: (v) => setState(() => v ? chosen.add(n) : chosen.remove(n)),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        Text(
          '${chosen.length} seleccionado${chosen.length == 1 ? '' : 's'}',
          style: TextStyle(color: ink.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: saving ? null : _savePantry,
          child: Text(chosen.isEmpty ? 'Empezar sin despensa' : 'Empezar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: saving
              ? null
              : () {
                  setState(chosen.clear);
                  _savePantry();
                },
          child: const Text('Saltar este paso'),
        ),
      ],
    );
  }
}
