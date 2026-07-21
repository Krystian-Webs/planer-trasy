import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'panel_tabs.dart';
import 'section_checkpoints.dart';
import 'section_elevation.dart';
import 'section_export.dart';
import 'section_pace.dart';
import 'section_pois.dart';
import 'section_project.dart';
import 'section_splits.dart';
import 'section_stops.dart';
import 'section_target.dart';
import 'section_tracks.dart';
import 'summary_row.dart';

/// The scrollable content shown inside the draggable [GlassBottomSheet] — a
/// direct port of the web app's left-hand panel sections. Which sections
/// show is driven by [tab], owned by [PlannerScreen] and selected via the
/// fixed [BottomNavBar] rather than a tab bar living in here — that way the
/// tab choice is always reachable even when the sheet is collapsed.
///
/// The drag handle and summary row are slivers in the *same* [CustomScrollView]
/// as the tab's sections (not separate widgets above it) — a
/// [DraggableScrollableSheet] only resizes in response to drags on the
/// Scrollable that owns its [scrollController], so anything outside that
/// single scrollable would be visually part of the sheet but inert to drag.
class PanelContent extends StatelessWidget {
  final PanelTab tab;
  final ScrollController? scrollController;
  final double bottomPadding;
  const PanelContent({super.key, required this.tab, this.scrollController, this.bottomPadding = 32});

  List<Widget> get _sections => switch (tab) {
        PanelTab.route => const [TracksSection(), StopsSection(), TargetSection()],
        PanelTab.points => const [CheckpointsSection(), PoiTypeChipsSection(), PoiListSection()],
        PanelTab.analysis => const [PaceSection(), ElevationSection(), SplitsSection(), Terrain3DSection()],
        PanelTab.project => const [ProjectSection(), ExportSection()],
      };

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        const SliverToBoxAdapter(child: _DragHandle()),
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SummaryRow()),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          sliver: SliverList.list(
            // Keyed so switching tabs swaps the sliver's children instead of
            // just rebuilding widgets of the same type in place — otherwise
            // e.g. TracksSection and CheckpointsSection could get matched to
            // the same element slot and swap state (like a text controller)
            // between unrelated sections.
            key: ValueKey(tab),
            children: _sections,
          ),
        ),
      ],
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
