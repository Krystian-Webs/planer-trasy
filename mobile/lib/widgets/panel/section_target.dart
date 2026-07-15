import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import 'ui_kit.dart';

class TargetSection extends StatefulWidget {
  const TargetSection({super.key});

  @override
  State<TargetSection> createState() => _TargetSectionState();
}

class _TargetSectionState extends State<TargetSection> {
  bool _customOpen = false;
  final _customCtrl = TextEditingController(text: '21.1');

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final target = c.targetKm;
    String status;
    Color statusColor = AppColors.ink;
    if (target == null) {
      status = 'Wybierz dystans, by śledzić postęp.';
    } else if (c.lastGeometry.length < 2) {
      status = 'Cel: ${fmtKm(target)} km. Wyznacz trasę, by zobaczyć postęp.';
    } else {
      final diff = c.totalMeters - target * 1000;
      final cur = fmtKm(c.totalMeters / 1000);
      if (diff.abs() <= 20) {
        status = '✅ Trasa ma dokładnie ${fmtKm(target)} km.';
        statusColor = AppColors.good;
      } else if (diff < 0) {
        status = 'Masz $cur km — brakuje ${(-diff).round()} m do ${fmtKm(target)} km. Wydłuż trasę.';
      } else {
        status = 'Masz $cur km — o ${diff.round()} m za dużo. Skróć trasę lub dociągnij metę.';
      }
    }
    final canSnap = target != null && c.totalMeters >= target * 1000;

    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Dystans docelowy'),
          Row(
            children: [
              Expanded(child: ActionButton(label: '5 km', primary: target == 5, onTap: () => c.setTargetKm(5))),
              const SizedBox(width: 8),
              Expanded(child: ActionButton(label: '10 km', primary: target == 10, onTap: () => c.setTargetKm(10))),
              const SizedBox(width: 8),
              ActionButton(label: 'inny', width: 58, onTap: () => setState(() => _customOpen = !_customOpen)),
            ],
          ),
          if (_customOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _customCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.bg,
                          contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.line)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('km', style: TextStyle(color: AppColors.inkDim, fontSize: 12.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ActionButton(
                        label: 'Ustaw cel',
                        primary: false,
                        compact: true,
                        onTap: () {
                          final v = double.tryParse(_customCtrl.text.replaceAll(',', '.'));
                          if (v != null && v > 0) {
                            c.setTargetKm(v);
                            c.toast('Cel ustawiony: ${fmtKm(v)} km');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 12.5, height: 1.5)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: '📍 Ustaw metę dokładnie na cel',
              onTap: canSnap ? c.snapFinishToTarget : null,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: c.proposing ? 'Szukam trasy…' : '✨ Zaproponuj trasę (pętla)',
              primary: true,
              onTap: c.proposing ? null : c.proposeLoopRoute,
            ),
          ),
          const HintText(
              'Buduj trasę, a aplikacja pokaże, ile brakuje do celu i postawi na trasie znacznik mety. „Zaproponuj trasę” układa pętlę o zadanej długości wokół startu — potem dopracuj ją, przeciągając punkty.'),
        ],
      ),
    );
  }
}
