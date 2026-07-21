import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../state/planner_controller.dart';
import '../theme/app_theme.dart';

/// Starts a fresh project — the shared "+" flow used by both the header
/// icon and the Projekt tab. If the current project has anything in it,
/// asks whether to save it to the routes library first rather than
/// silently discarding work.
Future<void> startNewProject(BuildContext context, PlannerController c) async {
  if (!c.hasContent) {
    c.newProject();
    return;
  }

  final choice = await showDialog<_NewProjectChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panelSolid,
      title: const Text('Nowa trasa', style: TextStyle(color: AppColors.ink)),
      content: const Text(
        'Masz niezapisaną trasę. Zapisać ją w „Moje trasy” zanim zaczniesz od nowa?',
        style: TextStyle(color: AppColors.inkDim),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _NewProjectChoice.discard),
          child: const Text('Nie zapisuj', style: TextStyle(color: AppColors.bad)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _NewProjectChoice.save),
          child: const Text('Zapisz', style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (choice == null) return;
  if (!context.mounted) return;

  if (choice == _NewProjectChoice.save) {
    final name = await _promptName(context, initial: c.projectName);
    if (name == null || name.trim().isEmpty) return; // cancelled the name prompt — keep the project untouched
    await LibraryService.saveNew(
      name: name.trim(),
      data: c.serialize(),
      tracks: c.tracks,
      poiCount: c.pois.length,
    );
    if (!context.mounted) return;
    c.toast('Zapisano „${name.trim()}" w bibliotece ✓');
  }

  c.newProject();
}

enum _NewProjectChoice { save, discard }

Future<String?> _promptName(BuildContext context, {required String initial}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panelSolid,
      title: const Text('Zapisz w bibliotece', style: TextStyle(color: AppColors.ink)),
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
