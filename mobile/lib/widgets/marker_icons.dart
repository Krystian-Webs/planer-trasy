import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Numbered start/waypoint/finish pin — a circular badge, port of waypointIcon().
class StopMarkerIcon extends StatelessWidget {
  final String label;
  final Color color;
  final bool dragging;
  const StopMarkerIcon({super.key, required this.label, required this.color, this.dragging = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: dragging ? 1.18 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 1), Color.lerp(color, Colors.black, 0.15)!],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 1))],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, height: 1),
        ),
      ),
    );
  }
}

/// Teardrop POI pin (rotated rounded-square), port of poiIcon().
class PoiMarkerIcon extends StatelessWidget {
  final PoiKind kind;
  final int? badge;
  final bool dragging;
  final bool selected;
  const PoiMarkerIcon({super.key, required this.kind, this.badge, this.dragging = false, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: dragging ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: kind.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2))],
                ),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Text(kind.icon, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -6,
                right: -6,
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: kind.color, width: 1.5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Text(
                        '$badge',
                        style: TextStyle(color: kind.color, fontWeight: FontWeight.bold, fontSize: 9, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small pill label for km markers along the route.
class KmLabel extends StatelessWidget {
  final int km;
  const KmLabel({super.key, required this.km});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.panelSolid,
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$km km', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}

/// Pulsing "you are here" GPS dot, iOS Maps style.
class MyLocationMarker extends StatefulWidget {
  final double? headingDeg;
  const MyLocationMarker({super.key, this.headingDeg});

  @override
  State<MyLocationMarker> createState() => _MyLocationMarkerState();
}

class _MyLocationMarkerState extends State<MyLocationMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0) * 0.35,
                child: Container(
                  width: 20 + t * 40,
                  height: 20 + t * 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3DA5F4)),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3DA5F4),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Target-distance finish flag marker.
class TargetFlagMarker extends StatelessWidget {
  final String label;
  const TargetFlagMarker({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.panelSolid,
        border: Border.all(color: AppColors.accent, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Text('🏁 $label', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
