import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import 'screens/planner_screen.dart';
import 'state/planner_controller.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(
    child: const PlanerTrasyApp(),
    adaptiveQuality: true,
    // `standard` is the library's own recommended default for interactive
    // widgets (GlassSegmentedControl, GlassTextField); `premium` trades that
    // reliability for texture-capture fidelity we don't need here.
    adaptiveConfig: const GlassAdaptiveScopeConfig(maxQuality: GlassQuality.standard),
    theme: GlassThemeData.simple(
      blur: 14,
      thickness: 28,
      quality: GlassQuality.standard,
    ),
  ));
}

class PlanerTrasyApp extends StatelessWidget {
  const PlanerTrasyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlannerController(),
      child: MaterialApp(
        title: 'Planer Trasy',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        home: const PlannerScreen(),
      ),
    );
  }
}
