import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'panel_tabs.dart';

/// Content height of [BottomNavBar] excluding the bottom safe-area inset —
/// kept as a constant so [PlannerScreen] can reserve exactly this much
/// space above it when sizing the draggable sheet's snap points.
const double kBottomNavContentHeight = 58;

/// Fixed, always-on-top bottom navigation. Unlike a tab bar that lives
/// inside the draggable sheet (and disappears when the sheet is collapsed),
/// this never goes away — switching sections never requires dragging
/// anything up first, matching the tab bars every other app already trained
/// users on.
class BottomNavBar extends StatelessWidget {
  final PanelTab selected;
  final ValueChanged<PanelTab> onChanged;
  const BottomNavBar({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomSafe),
      height: kBottomNavContentHeight + bottomSafe,
      decoration: BoxDecoration(
        color: AppColors.panelSolid.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: AppColors.lineSoft)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final t in kPanelTabs)
            _NavItem(
              info: t,
              selected: t.tab == selected,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(t.tab);
              },
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final PanelTabInfo info;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent2 : AppColors.inkDim;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info.icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              info.label,
              style: TextStyle(color: color, fontSize: 10.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
