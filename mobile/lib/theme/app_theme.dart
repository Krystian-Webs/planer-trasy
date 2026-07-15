import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Colors ported 1:1 from the web app's `:root` CSS variables (dark theme).
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0A0E13);
  static const panel = Color(0xF0141A22); // rgba(20,26,34,.94)
  static const panelSolid = Color(0xFF141A22);
  static const panel2 = Color(0xFF1C242F);
  static const panel3 = Color(0xFF232D3A);
  static const line = Color(0xFF2A3542);
  static const lineSoft = Color(0x12FFFFFF); // rgba(255,255,255,.07)
  static const ink = Color(0xFFEEF3F8);
  static const inkDim = Color(0xFF8FA0B0);
  static const accent = Color(0xFFFF6B1A);
  static const accent2 = Color(0xFFFF8A3D);
  static const accentSoft = Color(0x24FF6B1A); // rgba(255,107,26,.14)
  static const good = Color(0xFF33C27A);
  static const bad = Color(0xFFE23B4E);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent2, accent],
  );
}

/// POI type metadata, ported from the `POI` map in the web app.
class PoiKind {
  final String key;
  final String icon;
  final String label;
  final Color color;
  const PoiKind(this.key, this.icon, this.label, this.color);
}

const List<PoiKind> kPoiKinds = [
  PoiKind('checkpoint', '🔵', 'Punkt kontrolny', Color(0xFF3DA5F4)),
  PoiKind('water', '💧', 'Punkt wody', Color(0xFF17B6C9)),
  PoiKind('food', '🍌', 'Odżywianie', Color(0xFFF4B43D)),
  PoiKind('timing', '⏱️', 'Pomiar czasu', Color(0xFF9B5DE5)),
  PoiKind('wc', '🚻', 'Toaleta', Color(0xFF7D8A99)),
  PoiKind('medic', '➕', 'Pomoc med.', Color(0xFFE23B4E)),
  PoiKind('ambulance', '🚑', 'Karetka', Color(0xFF9B0E2A)),
  PoiKind('volunteer', '🙋', 'Wolontariusz', Color(0xFF27C24C)),
  PoiKind('police', '👮', 'Policja', Color(0xFF1F3AFF)),
  PoiKind('marshal', '🦺', 'Służba porządkowa', Color(0xFFFF8C00)),
  PoiKind('security', '🛡️', 'Ochrona', Color(0xFF34495E)),
  PoiKind('parking', '🅿️', 'Parking', Color(0xFF0A66C2)),
  PoiKind('arrow', '➡️', 'Kierunek / strzałka', Color(0xFFFF6B1A)),
  PoiKind('poi', '⭐', 'Punkt', Color(0xFFE67E22)),
];

PoiKind poiKindOf(String key) => kPoiKinds.firstWhere(
      (p) => p.key == key,
      orElse: () => kPoiKinds.last,
    );

const List<Color> kTrackColors = [
  Color(0xFFFF6B1A),
  Color(0xFF2F7BFF),
  Color(0xFF33C27A),
  Color(0xFFE23B4E),
  Color(0xFF9B59B6),
  Color(0xFFF1C40F),
  Color(0xFF16A085),
  Color(0xFFE67E22),
];

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: '.SF Pro Text',
    colorScheme: const ColorScheme.dark(
      surface: AppColors.bg,
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      error: AppColors.bad,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.accent,
    ),
  );
}
