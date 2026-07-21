import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import '../state/planner_controller.dart';
import '../widgets/map_view.dart';
import '../widgets/panel/bottom_nav_bar.dart';
import '../widgets/panel/glass_bottom_sheet.dart';
import '../widgets/panel/panel_tabs.dart';
import '../widgets/top_bar.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _mapController = MapController();
  final _sheetController = DraggableScrollableController();
  PanelTab _tab = PanelTab.route;
  int _lastToastSeq = 0;

  void _selectTab(PanelTab tab, double peekSize) {
    setState(() => _tab = tab);
    // Tapping a section while the sheet is collapsed should reveal it, not
    // just silently switch content the user can't see yet.
    if (_sheetController.isAttached && _sheetController.size <= peekSize + 0.02) {
      _sheetController.animateTo(0.52, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    if (c.toastSeq != _lastToastSeq) {
      _lastToastSeq = c.toastSeq;
      final msg = c.lastToast;
      if (msg != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) GlassToast.show(context, message: msg, type: GlassToastType.info, duration: const Duration(seconds: 3));
        });
      }
    }

    final navBarHeight = kBottomNavContentHeight + MediaQuery.paddingOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final peekSize = ((navBarHeight + 78) / screenHeight).clamp(0.14, 0.3);

    // The map is placed directly in `body`'s Stack (not in GlassScaffold's
    // `background` slot) so it stays hit-testable: `background` sits behind
    // an internal Scaffold whose body absorbs every tap across the whole
    // screen — even where nothing is painted — which silently swallowed all
    // map taps when the map lived there instead.
    return GlassScaffold(
      statusBarStyle: GlassStatusBarStyle.light,
      extendBody: true,
      edgeFade: false,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              mapController: _mapController,
              // "Draw route" needs nothing from the sheet to start working —
              // tapping the map places a stop immediately. "Place points"
              // does: you need a point *type* first, which lives in the
              // sheet's Punkty tab, and that tab shares a name with this
              // mode's own floating button — without this, switching to
              // "Punkty" here visibly does nothing, which reads as broken.
              onModeChanged: (m) {
                if (m == PlannerMode.poi) _selectTab(PanelTab.points, peekSize);
              },
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: TopBar(mapController: _mapController)),
          GlassBottomSheet(tab: _tab, controller: _sheetController, navBarHeight: navBarHeight),
          // Painted last so it always sits on top of the sheet, even at
          // "full" — switching sections should never require collapsing
          // whatever you were looking at first.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavBar(selected: _tab, onChanged: (t) => _selectTab(t, peekSize)),
          ),
        ],
      ),
    );
  }
}
