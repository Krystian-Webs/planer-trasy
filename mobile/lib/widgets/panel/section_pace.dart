import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import 'ui_kit.dart';

const _presets = [
  (label: '🏃 Bieg 6:00/km', sec: 360),
  (label: '⚡ Szybko 5:00/km', sec: 300),
  (label: '🏃 Trucht 7:00/km', sec: 420),
  (label: '🚶 Marsz 5 km/h', sec: 720),
];

String _fmtPace(int s) => '${s ~/ 60}:${(s % 60).round().toString().padLeft(2, '0')}';
String _fmtDur(double s) {
  final r = s.round();
  final h = r ~/ 3600, m = (r % 3600) ~/ 60, sec = r % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  return '$m:${sec.toString().padLeft(2, '0')}';
}

class PaceSection extends StatefulWidget {
  const PaceSection({super.key});

  @override
  State<PaceSection> createState() => _PaceSectionState();
}

class _PaceSectionState extends State<PaceSection> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmtPace(context.read<PlannerController>().paceSec));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final dur = c.estimatedDuration;
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Szacowany czas'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final p in _presets)
                SizedBox(
                  width: 160,
                  child: ActionButton(
                    label: p.label,
                    compact: true,
                    primary: c.paceSec == p.sec,
                    onTap: () {
                      c.setPaceSec(p.sec);
                      _ctrl.text = _fmtPace(p.sec);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Text('Własne tempo', style: TextStyle(color: AppColors.inkDim, fontSize: 12.5)),
                const Spacer(),
                SizedBox(
                  width: 74,
                  child: TextField(
                    controller: _ctrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.ink),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.line)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('min/km', style: TextStyle(color: AppColors.inkDim, fontSize: 12.5)),
                const SizedBox(width: 8),
                ActionButton(
                  label: 'Ustaw',
                  compact: true,
                  onTap: () {
                    final v = _ctrl.text.trim();
                    int? s;
                    if (v.contains(':')) {
                      final parts = v.split(':');
                      s = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
                    } else {
                      final f = double.tryParse(v.replaceAll(',', '.'));
                      if (f != null) s = (f * 60).round();
                    }
                    if (s != null && s > 0) {
                      c.setPaceSec(s);
                      c.toast('Tempo: ${_fmtPace(s)} min/km');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              StatTile(value: dur != null ? _fmtDur(dur.inSeconds.toDouble()) : '—', label: 'CZAS TRASY'),
              const SizedBox(width: 8),
              StatTile(value: _fmtPace(c.paceSec), label: 'MIN/KM'),
            ],
          ),
        ],
      ),
    );
  }
}
