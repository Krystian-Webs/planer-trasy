import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../state/planner_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/route_thumbnail.dart';

/// "Moje trasy" — a real second screen (not another tab in the sheet) that
/// lists every route saved to the local library, distinct from the single
/// autosave slot: rename, duplicate, delete, or open one into the editor.
class RoutesLibraryScreen extends StatefulWidget {
  const RoutesLibraryScreen({super.key});

  @override
  State<RoutesLibraryScreen> createState() => _RoutesLibraryScreenState();
}

class _RoutesLibraryScreenState extends State<RoutesLibraryScreen> {
  late Future<List<LibraryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = LibraryService.list();
  }

  void _reload() => setState(() => _future = LibraryService.list());

  Future<void> _saveCurrent() async {
    final c = context.read<PlannerController>();
    if (!c.hasContent) {
      c.toast('Brak trasy do zapisania — narysuj coś najpierw.');
      return;
    }
    final name = await _promptName(initial: c.projectName, title: 'Zapisz w bibliotece');
    if (name == null || name.trim().isEmpty) return;
    await LibraryService.saveNew(
      name: name.trim(),
      data: c.serialize(),
      tracks: c.tracks,
      poiCount: c.pois.length,
    );
    if (!mounted) return;
    c.toast('Zapisano „$name" w bibliotece ✓');
    _reload();
  }

  Future<String?> _promptName({required String initial, required String title}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelSolid,
        title: Text(title, style: const TextStyle(color: AppColors.ink)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.ink),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Zapisz')),
        ],
      ),
    );
  }

  Future<void> _open(LibraryEntry e) async {
    final c = context.read<PlannerController>();
    await c.loadProject(e.data);
    if (!mounted) return;
    c.toast('Wczytano „${e.name}" ✓');
    Navigator.of(context).pop();
  }

  Future<void> _rename(LibraryEntry e) async {
    final name = await _promptName(initial: e.name, title: 'Zmień nazwę');
    if (name == null || name.trim().isEmpty) return;
    await LibraryService.rename(e.id, name.trim());
    _reload();
  }

  Future<void> _duplicate(LibraryEntry e) async {
    await LibraryService.duplicate(e.id);
    _reload();
  }

  Future<void> _delete(LibraryEntry e) async {
    await LibraryService.delete(e.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text('Moje trasy', style: TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.accent, size: 28),
                    tooltip: 'Zapisz obecną trasę',
                    onPressed: _saveCurrent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LibraryEntry>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                  final entries = snap.data!;
                  if (entries.isEmpty) return const _EmptyLibrary();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _RouteCard(
                      entry: entries[i],
                      onTap: () => _open(entries[i]),
                      onRename: () => _rename(entries[i]),
                      onDuplicate: () => _duplicate(entries[i]),
                      onDelete: () => _delete(entries[i]),
                    ),
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: AppColors.inkDim),
            const SizedBox(height: 14),
            const Text('Biblioteka jest pusta', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Narysuj trasę na mapie, a potem zapisz ją tutaj przyciskiem ＋ — będziesz mieć do niej dostęp z każdej sesji.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkDim, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  const _RouteCard({required this.entry, required this.onTap, required this.onRename, required this.onDuplicate, required this.onDelete});

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Dziś';
    if (diff.inDays == 1) return 'Wczoraj';
    if (diff.inDays < 7) return '${diff.inDays} dni temu';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final km = (entry.distanceMeters / 1000).toStringAsFixed(2).replaceAll('.', ',');
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(color: AppColors.bad.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.panelSolid,
          title: const Text('Usunąć trasę?', style: TextStyle(color: AppColors.ink)),
          content: Text('„${entry.name}" zostanie usunięta z biblioteki.', style: const TextStyle(color: AppColors.inkDim)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń', style: TextStyle(color: AppColors.bad))),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
            child: Row(
              children: [
                RouteThumbnail(points: entry.previewLatLngs),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(_fmtDate(entry.savedAt), style: const TextStyle(color: AppColors.inkDim, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        children: [
                          _MiniStat(icon: Icons.straighten, text: '$km km'),
                          if (entry.trackCount > 1) _MiniStat(icon: Icons.alt_route, text: '${entry.trackCount} tras'),
                          if (entry.poiCount > 0) _MiniStat(icon: Icons.place, text: '${entry.poiCount} pkt.'),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppColors.panelSolid,
                  icon: const Icon(Icons.more_vert, color: AppColors.inkDim),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.line)),
                  onSelected: (v) {
                    if (v == 'rename') onRename();
                    if (v == 'duplicate') onDuplicate();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('Zmień nazwę', style: TextStyle(color: AppColors.ink))),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplikuj', style: TextStyle(color: AppColors.ink))),
                    PopupMenuItem(value: 'delete', child: Text('Usuń', style: TextStyle(color: AppColors.bad))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.accent2),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: AppColors.inkDim, fontSize: 11)),
      ],
    );
  }
}
