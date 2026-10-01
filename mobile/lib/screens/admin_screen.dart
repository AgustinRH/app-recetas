import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final search = TextEditingController();
  Map<String, dynamic> summary = const {};
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    tabs.addListener(() {
      if (!tabs.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    tabs.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final api = ref.read(apiProvider);
    final q = search.text.trim();
    try {
      final totals = await api.adminSummary();
      final List<Map<String, dynamic>> list;
      switch (tabs.index) {
        case 0:
          list = await api.adminReports(q: q);
        case 2:
          list = await api.adminComments(q: q);
        case 3:
          list = await api.adminUsers(q: q);
        default:
          list = await api.adminRecipes(q: q);
      }
      if (!mounted) return;
      setState(() {
        summary = totals;
        rows = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = _message(e);
      });
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
    }
    return 'No se pudo cargar';
  }

  Future<void> _confirm(String title, String body, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = summary['users'] ?? '–';
    final recipes = summary['recipes'] ?? '–';
    final comments = summary['comments'] ?? '–';
    final reports = summary['openReports'] ?? '–';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        bottom: TabBar(
          controller: tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Denuncias'),
            Tab(text: 'Recetas'),
            Tab(text: 'Comentarios'),
            Tab(text: 'Usuarios'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '$reports denuncias · $users usuarios · $recipes recetas · $comments comentarios',
              style: TextStyle(color: ink.withValues(alpha: 0.65)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                hintText: 'Buscar',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(child: Text(error!, style: const TextStyle(color: Colors.red)));
    }
    if (rows.isEmpty) return const Center(child: Text('Nada por aquí'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _tile(rows[i]),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> row) {
    if (tabs.index == 0) return _reportTile(row);
    if (tabs.index == 2) return _commentTile(row);
    if (tabs.index == 3) return _userTile(row);
    return _recipeTile(row);
  }

  Widget _card({required String title, required String subtitle, required Widget trailing}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: trailing,
      ),
    );
  }

  Widget _reportTile(Map<String, dynamic> row) {
    final note = (row['note'] as String?)?.trim() ?? '';
    final who = row['reporterEmail'] ?? row['reporterName'] ?? '';
    return _card(
      title: row['recipeTitle'] as String? ?? 'Receta',
      subtitle: '${row['reasonLabel'] ?? ''}\n$who${note.isEmpty ? '' : ' · $note'}',
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'open') {
            final id = row['recipeId'] as String?;
            if (id != null) context.push('/recipe/$id');
          } else if (value == 'dismiss') {
            _confirm(
              'Descartar denuncia',
              'La denuncia deja de aparecer aquí. La receta sigue publicada.',
              () => ref.read(apiProvider).adminDismissReport(row['id'] as String),
            );
          } else if (value == 'delete') {
            _confirm(
              'Eliminar receta',
              'Se borra «${row['recipeTitle']}» y sus denuncias. No se puede deshacer.',
              () => ref.read(apiProvider).adminDeleteRecipe(row['recipeId'] as String),
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('Ver receta')),
          PopupMenuItem(value: 'dismiss', child: Text('Descartar denuncia')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar receta')),
        ],
      ),
    );
  }

  Widget _recipeTile(Map<String, dynamic> row) {
    return _card(
      title: row['title'] as String? ?? '',
      subtitle: '${row['authorName'] ?? ''} · ${row['cuisine'] ?? ''}',
      trailing: IconButton(
        tooltip: 'Eliminar receta',
        icon: const Icon(Icons.delete_outline, color: terracotta),
        onPressed: () => _confirm(
          'Eliminar receta',
          'Se borra «${row['title']}» y sus comentarios. No se puede deshacer.',
          () => ref.read(apiProvider).adminDeleteRecipe(row['id'] as String),
        ),
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> row) {
    return _card(
      title: row['body'] as String? ?? '',
      subtitle: '${row['authorName'] ?? ''} · ${row['recipeTitle'] ?? ''}',
      trailing: IconButton(
        tooltip: 'Eliminar comentario',
        icon: const Icon(Icons.delete_outline, color: terracotta),
        onPressed: () => _confirm(
          'Eliminar comentario',
          'Se borra este comentario.',
          () => ref.read(apiProvider).adminDeleteComment(row['id'] as String),
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> row) {
    final banned = row['banned'] == true;
    final admin = row['isAdmin'] == true;
    return _card(
      title: row['displayName'] as String? ?? '',
      subtitle: '${row['email'] ?? 'sin email'} · ${row['recipesCount'] ?? 0} recetas'
          '${admin ? ' · admin' : ''}${banned ? ' · suspendido' : ''}',
      trailing: admin
          ? const Icon(Icons.verified_user_outlined, color: terracotta)
          : IconButton(
              tooltip: banned ? 'Reactivar' : 'Suspender',
              icon: Icon(banned ? Icons.lock_open : Icons.block, color: terracotta),
              onPressed: () => _confirm(
                banned ? 'Reactivar cuenta' : 'Suspender cuenta',
                banned
                    ? 'Esta persona podrá volver a entrar.'
                    : 'No podrá entrar hasta que la reactives.',
                () => ref.read(apiProvider).adminSetBanned(row['id'] as String, !banned),
              ),
            ),
    );
  }
}
