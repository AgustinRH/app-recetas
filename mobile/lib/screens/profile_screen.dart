import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/recipe_grid_card.dart';

Future<void> _deleteAccount(BuildContext context, WidgetRef ref, bool isAdmin) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Borrar mi cuenta'),
      content: Text(
        isAdmin
            ? 'Se borran tu perfil, tu despensa, tu plan, tus recetas y tu acceso. Dejarás de ser administrador. No se puede deshacer.'
            : 'Se borran tu perfil, tu despensa, tu plan, tus recetas y tu acceso. No se puede deshacer.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Borrar cuenta'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(apiProvider).deleteAccount();
    await ref.read(authProvider.notifier).logout();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiClient.describeError(e))),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final stats = ref.watch(statsProvider).value ?? const ProfileStats();
    final name = profile?.displayName ?? '';
    final since = _memberSince(profile?.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Editar preferencias',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/preferences'),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statsProvider);
          await ref.read(statsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: terracotta,
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      if (profile?.email != null)
                        Text(
                          profile!.email!,
                          style: TextStyle(color: ink.withValues(alpha: 0.6)),
                        ),
                      if (since != null)
                        Text(
                          since,
                          style: TextStyle(color: ink.withValues(alpha: 0.5), fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _stat('${stats.recipesCount}', 'recetas'),
                _stat('${stats.likesReceived}', 'me gusta'),
                _stat('${stats.savedCount}', 'guardadas'),
                _stat('${stats.cookedCount}', 'cocinadas'),
                _stat('${stats.pantryCount}', 'en despensa'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${stats.followersCount} seguidores · ${stats.followingCount} siguiendo',
              style: TextStyle(color: ink.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 12),
            _streakCard(stats),
            const SizedBox(height: 12),
            _badges(stats),
            const SizedBox(height: 12),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined, color: terracotta),
                title: const Text('Plan de la semana', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Comida, cena y la compra de lo que falta'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/planner'),
              ),
            ),
            if (profile?.isAdmin == true) ...[
              const SizedBox(height: 10),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: terracotta),
                  title: const Text('Administración', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Denuncias, recetas, comentarios y usuarios'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _prefsCard(context, profile, stats),
            const SizedBox(height: 20),
            _sectionTitle(context, 'Mis recetas'),
            const SizedBox(height: 8),
            _RecipeStrip(
              loader: () => ref.read(apiProvider).myRecipes(),
              emptyText: 'Todavía no has publicado ninguna receta.',
              emptyAction: TextButton.icon(
                onPressed: () => context.push('/publish'),
                icon: const Icon(Icons.add),
                label: const Text('Publicar la primera'),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle(context, 'Guardadas'),
            const SizedBox(height: 8),
            _RecipeStrip(
              loader: () => ref.read(apiProvider).savedRecipes(),
              emptyText: 'Guarda recetas desde su ficha para tenerlas a mano.',
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/privacidad'),
                  child: const Text('Privacidad'),
                ),
                Text('·', style: TextStyle(color: ink.withValues(alpha: 0.4))),
                TextButton(
                  onPressed: () => context.push('/condiciones'),
                  child: const Text('Condiciones'),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _deleteAccount(context, ref, profile?.isAdmin == true),
              child: const Text('Borrar mi cuenta', style: TextStyle(color: terracotta)),
            ),
          ],
        ),
      ),
    );
  }

  String? _memberSince(DateTime? d) {
    if (d == null) return null;
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return 'En DishToday desde ${months[d.month - 1]} de ${d.year}';
  }

  Widget _streakCard(ProfileStats stats) {
    final days = stats.streak;
    final title = days == 0
        ? 'Sin racha'
        : days == 1
            ? 'Racha de 1 día'
            : 'Racha de $days días';
    final hint = days == 0
        ? 'Marca «La he cocinado» en una receta para empezarla.'
        : !stats.cookedToday
            ? 'Cocina hoy para no romperla.'
            : stats.bestStreak > days
                ? 'Tu mejor racha: ${stats.bestStreak} días.'
                : 'Hoy ya cuenta.';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        leading: const Icon(Icons.local_fire_department_outlined, color: terracotta),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(hint),
      ),
    );
  }

  Widget _badges(ProfileStats stats) {
    if (stats.badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Insignias', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.badges.map((badge) {
            final color = badge.earned ? terracotta : ink.withValues(alpha: 0.35);
            return Container(
              width: 168,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    badge.earned ? Icons.military_tech : Icons.military_tech_outlined,
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.name,
                          style: TextStyle(fontWeight: FontWeight.w800, color: color),
                        ),
                        Text(
                          badge.hint,
                          style: TextStyle(fontSize: 11, color: ink.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: ink.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _prefsCard(BuildContext context, UserProfile? profile, ProfileStats stats) {
    final diets = profile?.diets ?? const [];
    final allergies = profile?.allergies ?? const [];
    Widget row(IconData icon, String label, List<String> values, String empty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: ink.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: values.isEmpty
                  ? Text(empty, style: TextStyle(color: ink.withValues(alpha: 0.5)))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: values
                          .map((v) => Chip(
                                label: Text(v),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          row(Icons.eco_outlined, 'Dieta', diets, 'Sin restricciones'),
          row(Icons.warning_amber_outlined, 'Alergias', allergies, 'Ninguna'),
          if (stats.topCuisines.isNotEmpty)
            row(Icons.public, 'Cocinas', stats.topCuisines, ''),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/preferences'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, {VoidCallback? onSeeAll}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('Ver todas')),
      ],
    );
  }
}

class _RecipeStrip extends StatelessWidget {
  const _RecipeStrip({
    required this.loader,
    required this.emptyText,
    this.emptyAction,
  });

  final Future<List<RecipeCard>> Function() loader;
  final String emptyText;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecipeCard>>(
      future: loader(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('No se pudo cargar', style: TextStyle(color: ink.withValues(alpha: 0.6)));
        }
        if (!snap.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emptyText, style: TextStyle(color: ink.withValues(alpha: 0.6))),
                if (emptyAction != null) emptyAction!,
              ],
            ),
          );
        }
        return SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 150,
              child: RecipeGridCard(recipe: items[i], compact: true),
            ),
          ),
        );
      },
    );
  }
}
