import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';

class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.lineSoft))),
      child: Row(
        children: [
          _Stat(value: fmtKm(c.sumMeters / 1000), label: 'km trasy', accent: true),
          _divider(),
          _Stat(value: '${c.checkpointCount}', label: 'pkt. kontrolne'),
          _divider(),
          _Stat(value: '${c.pois.length}', label: 'wszystkie pkt.'),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.lineSoft);
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;
  const _Stat({required this.value, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => accent
                ? AppColors.accentGradient.createShader(bounds)
                : const LinearGradient(colors: [AppColors.ink, AppColors.ink]).createShader(bounds),
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -.3)),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: AppColors.inkDim, fontSize: 9.5, letterSpacing: .8, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
