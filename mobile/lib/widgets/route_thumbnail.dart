import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../theme/app_theme.dart';

/// Small sketch of a route's shape (normalized to fit the given box),
/// used as a lightweight thumbnail in the routes library — no map tiles,
/// no network, just the path.
class RouteThumbnail extends StatelessWidget {
  final List<LatLng> points;
  final double size;
  const RouteThumbnail({super.key, required this.points, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(8),
      child: points.length >= 2
          ? CustomPaint(painter: _RoutePainter(points))
          : const Center(child: Icon(Icons.route_outlined, color: AppColors.inkDim, size: 20)),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<LatLng> points;
  _RoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final latSpan = (maxLat - minLat).abs().clamp(1e-6, double.infinity);
    final lngSpan = (maxLng - minLng).abs().clamp(1e-6, double.infinity);
    // Longitude degrees compress horizontally with latitude — correct so a
    // north-south loop doesn't look squashed.
    final latCorrection = latSpan;
    final lngCorrection = lngSpan * (0.6 + 0.4 * (1 - (minLat.abs() / 90)));
    final scale = latCorrection > lngCorrection ? latCorrection : lngCorrection;

    Offset toOffset(LatLng p) {
      final x = ((p.longitude - minLng) / scale) * size.width;
      final y = (1 - (p.latitude - minLat) / scale) * size.height;
      return Offset(x.clamp(0, size.width), y.clamp(0, size.height));
    }

    final path = Path()..moveTo(toOffset(points.first).dx, toOffset(points.first).dy);
    for (final p in points.skip(1)) {
      final o = toOffset(p);
      path.lineTo(o.dx, o.dy);
    }
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = AppColors.good;
    canvas.drawCircle(toOffset(points.first), 2.6, dotPaint);
    final endPaint = Paint()..color = Colors.white;
    canvas.drawCircle(toOffset(points.last), 2.6, endPaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => oldDelegate.points != points;
}
