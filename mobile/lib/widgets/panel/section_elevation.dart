import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import 'ui_kit.dart';

class ElevationSection extends StatelessWidget {
  const ElevationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final profile = c.elevationProfile;
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Profil wysokościowy'),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: c.elevationLoading ? 'Liczę…' : '📈 Policz przewyższenia',
              onTap: c.elevationLoading ? null : c.computeElevation,
            ),
          ),
          if (profile != null && profile.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 130,
              padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
              decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  minY: c.elevMin,
                  maxY: c.elevMax == c.elevMin ? c.elevMax + 1 : c.elevMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (final e in profile) FlSpot(e.key, e.value)],
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: AppColors.accent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.accent.withValues(alpha: 0.5), AppColors.accent.withValues(alpha: 0.05)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                StatTile(value: '↗ ${c.elevAsc.round()} m', label: 'PODBIEGI'),
                const SizedBox(width: 8),
                StatTile(value: '↘ ${c.elevDesc.round()} m', label: 'ZBIEGI'),
                const SizedBox(width: 8),
                StatTile(value: '${c.elevMin.round()}–${c.elevMax.round()}', label: 'M N.P.M.'),
              ],
            ),
          ],
          const HintText('Pobiera wysokość terenu wzdłuż trasy i pokazuje podbiegi/zbiegi. Przelicz ponownie po zmianie trasy.'),
        ],
      ),
    );
  }
}
