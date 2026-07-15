import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/planner_models.dart';
import '../state/planner_controller.dart';
import '../theme/app_theme.dart';

/// Bottom sheet grid to pick a POI type when tapping the map in "poi" mode —
/// port of openTypeChooser().
void showPoiTypeSheet(BuildContext context, {required ValueChanged<String> onPick}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GlassSheetShell(
      title: 'Co tu dodać?',
      // Flexible (not shrinkWrap/NeverScrollableScrollPhysics) lets the grid
      // take only the space the sheet actually has and scroll internally —
      // with 14 POI kinds in 2 columns, a shrink-wrapped never-scrollable
      // grid demanded more height than the default (half-screen) sheet had,
      // overflowing past the bottom edge.
      child: Flexible(
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 3.1,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final k in kPoiKinds)
              _TypeTile(
                kind: k,
                onTap: () {
                  Navigator.of(context).pop();
                  onPick(k.key);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Quick-edit sheet for an existing POI (name / note / delete) — reachable
/// both from the map marker tap and from the panel's POI list.
void showPoiEditSheet(BuildContext context, {required PlannerController controller, required Poi poi}) {
  final nameCtrl = TextEditingController(text: poi.name);
  final noteCtrl = TextEditingController(text: poi.note);
  final kind = poiKindOf(poi.type);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _GlassSheetShell(
        title: '${kind.icon} ${kind.label}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetField(controller: nameCtrl, hint: 'Nazwa (np. ${kind.label})'),
            const SizedBox(height: 8),
            _SheetField(controller: noteCtrl, hint: 'Notatka — obsada, sprzęt, godziny otwarcia', maxLines: 3),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label: 'Usuń',
                    color: AppColors.bad,
                    onTap: () {
                      controller.removePoi(poi.id);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    label: 'Zapisz',
                    color: AppColors.accent,
                    onTap: () {
                      controller.updatePoi(poi.id, name: nameCtrl.text, note: noteCtrl.text);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Simple destructive-action sheet for a route stop marker.
void showStopActionSheet(BuildContext context, {required String title, required VoidCallback onDelete}) {
  showCupertinoModalPopup(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(ctx).pop();
            onDelete();
          },
          child: const Text('✕ Usuń ten punkt'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Anuluj'),
      ),
    ),
  );
}

class _TypeTile extends StatelessWidget {
  final PoiKind kind;
  final VoidCallback onTap;
  const _TypeTile({required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              Text(kind.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(kind.label,
                    style: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassSheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        // Caps how tall the sheet can grow — without this, a Flexible +
        // scrollable child (like the POI type grid) fills every pixel
        // `isScrollControlled` makes available, right up to the status bar,
        // leaving no map visible above it to tap-to-dismiss.
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panelSolid,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.inkDim.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _SheetField({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.ink, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5F6F80), fontSize: 13),
        filled: true,
        fillColor: AppColors.panel2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }
}
