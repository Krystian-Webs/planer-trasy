import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/planner_models.dart';
import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import 'ui_kit.dart';

class TracksSection extends StatelessWidget {
  const TracksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Trasy (warianty / kolory)'),
          for (final t in c.tracks) _TrackRow(track: t),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ActionButton(label: '＋ Dodaj kolejną trasę (inny kolor)', onTap: c.addTrack),
          ),
          const HintText(
              'Każda trasa ma swój kolor i jest widoczna na tej samej mapie. Ikona ołówka wybiera, którą teraz rysujesz. Np. pętla 5 km na pomarańczowo + dodatkowe 4 km na niebiesko = wariant 10 km.'),
        ],
      ),
    );
  }
}

class _TrackRow extends StatefulWidget {
  final RouteTrack track;
  const _TrackRow({required this.track});

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.track.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final t = widget.track;
    final isActive = c.activeTrack?.id == t.id;
    if (_nameCtrl.text != t.name) _nameCtrl.text = t.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accentSoft : AppColors.panel2,
        border: Border.all(color: isActive ? AppColors.accent : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => c.setActiveTrack(t.id),
            child: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(left: 4, right: 8),
              decoration: BoxDecoration(color: Color(t.colorValue), shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              onSubmitted: (v) => c.renameTrack(t.id, v),
              onChanged: (v) => t.name = v,
              style: const TextStyle(color: AppColors.ink, fontSize: 13),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          Text(
            '${fmtKm(t.meters / 1000)} km',
            style: const TextStyle(color: AppColors.inkDim, fontSize: 12),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Text(isActive ? '✏️' : '✎', style: const TextStyle(fontSize: 14)),
            onPressed: () => c.setActiveTrack(t.id),
          ),
          if (c.tracks.length > 1)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16, color: AppColors.inkDim),
              onPressed: () => c.removeTrack(t.id),
            ),
        ],
      ),
    );
  }
}
