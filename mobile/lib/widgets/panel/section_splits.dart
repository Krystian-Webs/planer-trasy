import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import 'ui_kit.dart';

String _fmtDur(double s) {
  final r = s.round();
  final h = r ~/ 3600, m = (r % 3600) ~/ 60, sec = r % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  return '$m:${sec.toString().padLeft(2, '0')}';
}

class SplitsSection extends StatelessWidget {
  const SplitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final splits = c.computeSplits();
    if (splits.isEmpty) return const SizedBox.shrink();
    final hasElev = splits.first.ascent != null;
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(hasElev ? 'Odcinki co 1 km (z uwzgl. podbiegów)' : 'Odcinki co 1 km'),
          Container(
            decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _HeaderRow(hasElev: hasElev),
                for (var i = 0; i < splits.length; i++) _SplitRowWidget(row: splits[i], last: i == splits.length - 1),
              ],
            ),
          ),
          if (!hasElev)
            const HintText('Policz przewyższenia powyżej, by tempo na odcinkach uwzględniało podbiegi.'),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool hasElev;
  const _HeaderRow({required this.hasElev});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.inkDim, fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: .4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          const SizedBox(width: 28, child: Text('KM', style: style)),
          const Expanded(flex: 3, child: Text('ODCINEK', style: style)),
          if (hasElev) const Expanded(flex: 2, child: Text('↗ / ↘', style: style, textAlign: TextAlign.center)),
          const Expanded(flex: 2, child: Text('ŁĄCZNIE', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _SplitRowWidget extends StatelessWidget {
  final SplitRow row;
  final bool last;
  const _SplitRowWidget({required this.row, required this.last});

  @override
  Widget build(BuildContext context) {
    final partial = row.distanceMeters < 950;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.lineSoft))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${row.km}', style: const TextStyle(color: AppColors.accent2, fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              partial ? '${_fmtDur(row.splitSeconds)}  (${(row.distanceMeters).round()} m)' : _fmtDur(row.splitSeconds),
              style: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (row.ascent != null)
            Expanded(
              flex: 2,
              child: Text(
                '${row.ascent!.round()}/${row.descent!.round()} m',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkDim, fontSize: 11.5),
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtDur(row.cumulativeSeconds),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.inkDim, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
