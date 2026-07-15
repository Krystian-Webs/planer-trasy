import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/app_theme.dart';
import 'section_checkpoints.dart';
import 'section_elevation.dart';
import 'section_export.dart';
import 'section_pace.dart';
import 'section_pois.dart';
import 'section_project.dart';
import 'section_stops.dart';
import 'section_target.dart';
import 'section_tracks.dart';
import 'summary_row.dart';

/// The scrollable content shown inside the bottom [GlassBottomSheet] — a
/// direct port of the web app's left-hand panel sections, grouped into tabs
/// so finding a specific setting doesn't mean scrolling past ten others.
///
/// The drag handle, summary row and tab bar are slivers in the *same*
/// [CustomScrollView] as the tab's sections (not separate widgets above it,
/// and not a nested per-tab scroll view) — a [DraggableScrollableSheet] only
/// resizes in response to drags on the Scrollable that owns its
/// [scrollController], so anything outside that single scrollable would be
/// visually part of the sheet but inert to drag; a second, nested scrollable
/// per tab would instead fight the outer one over the same drag gesture.
class PanelContent extends StatefulWidget {
  final ScrollController? scrollController;
  const PanelContent({super.key, this.scrollController});

  @override
  State<PanelContent> createState() => _PanelContentState();
}

enum _PanelTab { route, points, analysis, project }

class _PanelContentState extends State<PanelContent> {
  _PanelTab _tab = _PanelTab.route;

  static const _tabs = [
    (_PanelTab.route, '🧭', 'Trasa'),
    (_PanelTab.points, '📍', 'Punkty'),
    (_PanelTab.analysis, '📈', 'Analiza'),
    (_PanelTab.project, '📁', 'Projekt'),
  ];

  List<Widget> get _sections => switch (_tab) {
        _PanelTab.route => const [TracksSection(), StopsSection(), TargetSection(), PaceSection()],
        _PanelTab.points => const [CheckpointsSection(), PoiTypeChipsSection(), PoiListSection()],
        _PanelTab.analysis => const [ElevationSection(), Terrain3DSection()],
        _PanelTab.project => const [ProjectSection(), ExportSection()],
      };

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        const SliverToBoxAdapter(child: _DragHandle()),
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SummaryRow()),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _PanelTabBar(
              selected: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList.list(
            // Keyed so switching tabs swaps the sliver's children instead of
            // just rebuilding widgets of the same type in place — otherwise
            // e.g. TracksSection and CheckpointsSection could get matched to
            // the same element slot and swap state (like a text controller)
            // between unrelated sections.
            key: ValueKey(_tab),
            children: _sections,
          ),
        ),
      ],
    );
  }
}

class _PanelTabBar extends StatelessWidget {
  final _PanelTab selected;
  final ValueChanged<_PanelTab> onChanged;
  const _PanelTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GlassSegmentedControl(
      segments: [for (final t in _PanelContentState._tabs) GlassSegment(label: '${t.$2} ${t.$3}')],
      selectedIndex: _PanelContentState._tabs.indexWhere((t) => t.$1 == selected),
      onSegmentSelected: (i) => onChanged(_PanelContentState._tabs[i].$1),
      height: 38,
      quality: GlassQuality.standard,
      backgroundColor: AppColors.panel2,
      indicatorColor: AppColors.accent,
      selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
      unselectedTextStyle: const TextStyle(color: AppColors.inkDim, fontWeight: FontWeight.w600, fontSize: 11.5),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9, bottom: 3),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.inkDim.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
