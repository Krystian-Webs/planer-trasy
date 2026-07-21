import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'panel_content.dart';
import 'panel_tabs.dart';

/// The draggable panel over the map — sits behind the fixed [BottomNavBar],
/// which reserves [navBarHeight] at the bottom so the sheet's own peek state
/// (drag handle + summary row) rests just above it instead of underneath it.
///
/// Uses Flutter's own [DraggableScrollableSheet] instead of the package's
/// `GlassModalSheet` — that widget's custom pointer-tracking (needed for its
/// jelly drag physics) gets permanently wedged after a touch near its top
/// edge misses a matching pointer-up (a documented class of bug in
/// `liquid_glass_widgets` for iOS gesture-arena drops), which silently
/// swallows every touch on the whole screen afterwards, including taps on
/// the map far outside the sheet. `DraggableScrollableSheet` is a core
/// Flutter widget with no custom gesture state machine, so it can't wedge,
/// and it still gives the "peek / half / full" snap behavior via `snapSizes`.
class GlassBottomSheet extends StatelessWidget {
  final PanelTab tab;
  final DraggableScrollableController controller;
  final double navBarHeight;
  const GlassBottomSheet({super.key, required this.tab, required this.controller, required this.navBarHeight});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Peek shows just the drag handle + summary stats, resting right above
    // the fixed nav bar — not the old design's tab bar, since that now lives
    // in the always-visible BottomNavBar instead of scrolling away with it.
    final peekSize = ((navBarHeight + 78) / screenHeight).clamp(0.14, 0.3);

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: peekSize,
      minChildSize: peekSize,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: [peekSize, 0.52, 0.94],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: const Border(top: BorderSide(color: AppColors.line)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, -4)),
                ],
              ),
              // The drag handle lives inside PanelContent's own scroll view
              // (as its first sliver) rather than here, so dragging it
              // actually resizes the sheet — see PanelContent's doc comment.
              child: PanelContent(tab: tab, scrollController: scrollController, bottomPadding: navBarHeight + 24),
            ),
          ),
        );
      },
    );
  }
}
