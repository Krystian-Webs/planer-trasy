import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import 'ui_kit.dart';

class CheckpointsSection extends StatefulWidget {
  const CheckpointsSection({super.key});

  @override
  State<CheckpointsSection> createState() => _CheckpointsSectionState();
}

class _CheckpointsSectionState extends State<CheckpointsSection> {
  final _ctrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Rozmieść punkty kontrolne'),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Co równy dystans wzdłuż trasy', style: TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 9),
                Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _ctrl,
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
                        label: 'Rozmieść →',
                        compact: true,
                        onTap: () {
                          final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
                          if (v != null) c.distributeCheckpoints(v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SwitchRow(
            title: 'Słupki kilometrowe',
            subtitle: 'Znaczniki co 1 km na mapie',
            value: c.showKm,
            onChanged: c.toggleShowKm,
          ),
        ],
      ),
    );
  }
}
