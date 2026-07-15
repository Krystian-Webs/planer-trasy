import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import '../state/planner_controller.dart';
import '../widgets/map_view.dart';
import '../widgets/panel/glass_bottom_sheet.dart';
import '../widgets/top_bar.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _mapController = MapController();
  int _lastToastSeq = 0;

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
          Positioned.fill(child: MapView(mapController: _mapController)),
          Positioned(top: 0, left: 0, right: 0, child: TopBar(mapController: _mapController)),
          const GlassBottomSheet(),
        ],
      ),
    );
  }
}
