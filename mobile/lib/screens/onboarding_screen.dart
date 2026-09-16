import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

const dietOptions = ['vegana', 'vegetariana', 'keto', 'sin gluten'];
const allergyOptions = ['gluten', 'lactosa', 'frutos secos', 'marisco', 'huevo'];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final name = TextEditingController();
  final diets = <String>{};
  final allergies = <String>{};

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu cocina')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('¿Cómo te llamamos?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: name,
            decoration: const InputDecoration(hintText: 'Nombre o apodo'),
          ),
          const SizedBox(height: 24),
          const Text('Dieta', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
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
          const SizedBox(height: 16),
          const Text('Alergias', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
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
            onPressed: () async {
              final n = name.text.trim();
              if (n.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Escribe un nombre')),
                );
                return;
              }
              await ref.read(authProvider.notifier).updateProfile(
                    displayName: n,
                    diets: diets.toList(),
                    allergies: allergies.toList(),
                  );
            },
            child: const Text('Empezar'),
          ),
        ],
      ),
    );
  }
}
