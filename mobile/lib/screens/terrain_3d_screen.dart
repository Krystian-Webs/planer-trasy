import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

/// First-person-style 3D flyover of the route: satellite imagery (Esri,
/// free, no API key) draped over real terrain relief, with extruded 3D
/// buildings (OpenFreeMap's free building footprints/heights) popped up on
/// top — a "hybrid" look like Apple/Google Maps' satellite+3D mode, so the
/// actual ground (fields, tree cover, rooftops) is visible in photo detail
/// instead of a stylized/schematic map. The camera is always oriented along
/// the road (bearing = direction of travel, steep near-horizon tilt) rather
/// than a plain top-down/oblique aerial view.
///
/// Also offers an automatic flyover: the camera flies along the route at a
/// constant ground speed, facing the direction of travel, like a guided tour.
class Terrain3DScreen extends StatefulWidget {
  final List<ll.LatLng> geometry;
  const Terrain3DScreen({super.key, required this.geometry});

  @override
  State<Terrain3DScreen> createState() => _Terrain3DScreenState();
}

class _Terrain3DScreenState extends State<Terrain3DScreen> with SingleTickerProviderStateMixin {
  MapLibreMapController? _controller;
  AnimationController? _flightController;
  DateTime? _lastCameraUpdate;
  double _lastBearing = 0;

  late final List<double> _cumulativeDistance;
  late final double _totalDistance;

  static const _flightSpeedMps = 12.0; // brisk flight pace
  static const _flightLookAheadMeters = 25.0;
  static const _cameraUpdateInterval = Duration(milliseconds: 66); // ~15fps over the platform channel

  // Steep-but-still-supported pitch: the underlying MapLibre Native SDK
  // caps camera tilt (60° normally, higher once a style enables terrain) —
  // requesting more than it allows just clamps to its max, so asking for a
  // near-horizon angle here always gets us whatever the ceiling actually is.
  static const _staticTilt = 72.0;
  static const _flightTilt = 82.0;
  static const _flightZoom = 18.0;

  /// Esri World Imagery — free, no API key, the same source used for the
  /// "Satelitarna" layer on the main map.
  static const _satelliteSource = {
    'type': 'raster',
    'tiles': ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
    'tileSize': 256,
    'maxzoom': 19,
    'attribution': '© Esri',
  };
  static const _demSource = {
    'type': 'raster-dem',
    'tiles': ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
    'encoding': 'terrarium',
    'tileSize': 256,
    'maxzoom': 14,
  };
  // OpenFreeMap's vector tiles, used only for building footprints/heights —
  // everything else about the ground (fields, roads, roofs) comes from the
  // satellite photo instead of this source's land-use/road styling.
  static const _buildingSource = {'type': 'vector', 'url': 'https://tiles.openfreemap.org/planet'};

  static final _styleMap = {
    'version': 8,
    'sources': {
      'satellite': _satelliteSource,
      'dem': _demSource,
      'openmaptiles': _buildingSource,
    },
    'layers': [
      {'id': 'satellite', 'type': 'raster', 'source': 'satellite'},
      {
        'id': 'building-3d',
        'type': 'fill-extrusion',
        'source': 'openmaptiles',
        'source-layer': 'building',
        'minzoom': 13,
        'paint': {
          'fill-extrusion-base': ['get', 'render_min_height'],
          'fill-extrusion-height': ['get', 'render_height'],
          'fill-extrusion-color': '#e8e8e8',
          'fill-extrusion-opacity': 0.92,
          'fill-extrusion-vertical-gradient': true,
        },
      },
    ],
    'terrain': {'source': 'dem', 'exaggeration': 1.3},
  };

  static final String _styleJson = jsonEncode(_styleMap);

  @override
  void initState() {
    super.initState();
    const dist = ll.Distance(roundResult: false);
    final cumulative = <double>[0];
    for (var i = 1; i < widget.geometry.length; i++) {
      cumulative.add(cumulative.last + dist.distance(widget.geometry[i - 1], widget.geometry[i]));
    }
    _cumulativeDistance = cumulative;
    _totalDistance = cumulative.last;
    if (widget.geometry.length >= 2) {
      _lastBearing = dist.bearing(widget.geometry.first, widget.geometry[1]);
    }
  }

  @override
  void dispose() {
    _flightController?.dispose();
    super.dispose();
  }

  bool get _isFlying => _flightController?.isAnimating ?? false;

  @override
  Widget build(BuildContext context) {
    final mid = widget.geometry[widget.geometry.length ~/ 2];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _styleJson,
            initialCameraPosition: CameraPosition(
              target: LatLng(mid.latitude, mid.longitude),
              zoom: 16,
              tilt: _staticTilt,
              // Faces the route's own starting direction instead of an
              // arbitrary fixed angle, so even the still preview already
              // reads as "looking down the road", not an aerial view.
              bearing: _bearingAtDistance(0),
            ),
            rotateGesturesEnabled: !_isFlying,
            tiltGesturesEnabled: !_isFlying,
            scrollGesturesEnabled: !_isFlying,
            zoomGesturesEnabled: !_isFlying,
            compassEnabled: true,
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: _onStyleLoaded,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: _pillButton('✕ Zamknij 3D', () => Navigator.of(context).pop()),
          ),
          if (widget.geometry.length >= 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Center(
                child: _pillButton(
                  _isFlying ? '⏸ Zatrzymaj przelot' : '▶ Odtwórz przelot',
                  _isFlying ? _stopFlight : _startFlight,
                ),
              ),
            ),
          if (_flightController != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: AnimatedBuilder(
                animation: _flightController!,
                builder: (_, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _flightController!.value,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFff6b1a)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF141A22),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;
    final coords = widget.geometry.map((p) => [p.longitude, p.latitude]).toList();
    try {
      await c.addGeoJsonSource('route', {
        'type': 'Feature',
        'properties': {},
        'geometry': {'type': 'LineString', 'coordinates': coords},
      });
      await c.addLineLayer(
        'route',
        'route-line',
        const LineLayerProperties(
          lineColor: '#ff6b1a',
          lineWidth: 5.0,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
      for (final p in widget.geometry) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      await c.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        left: 60,
        right: 60,
        top: 100,
        bottom: 60,
      ));
    } catch (_) {
      // Terrain / route overlay is best-effort — a plain pitched base map
      // is still a reasonable fallback if the style or SDK version rejects it.
    }
  }

  /// Index of the polyline segment containing distance [d] — i.e. the `lo`
  /// such that `_cumulativeDistance[lo] <= d <= _cumulativeDistance[lo + 1]`.
  int _segmentIndexAtDistance(double d) {
    if (d <= 0) return 0;
    if (d >= _totalDistance) return _cumulativeDistance.length - 2;
    var lo = 0, hi = _cumulativeDistance.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (_cumulativeDistance[mid] <= d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  ll.LatLng _positionAtDistance(double d) {
    final geometry = widget.geometry;
    if (d <= 0) return geometry.first;
    if (d >= _totalDistance) return geometry.last;
    final lo = _segmentIndexAtDistance(d);
    final segStart = _cumulativeDistance[lo];
    final segEnd = _cumulativeDistance[lo + 1];
    final segFrac = segEnd > segStart ? (d - segStart) / (segEnd - segStart) : 0.0;
    final p1 = geometry[lo];
    final p2 = geometry[lo + 1];
    return ll.LatLng(
      p1.latitude + (p2.latitude - p1.latitude) * segFrac,
      p1.longitude + (p2.longitude - p1.longitude) * segFrac,
    );
  }

  /// Heading to face at distance [d], looking [_flightLookAheadMeters] ahead.
  ///
  /// A straight chord from the camera's position to a single point further
  /// down the road "cuts" any corner that falls inside that span — the
  /// camera would face across the turn instead of rotating through it,
  /// reading as if it were drifting sideways rather than steering. Instead,
  /// this walks the actual polyline vertices inside the look-ahead window
  /// and averages each sub-segment's bearing as a unit vector, weighted by
  /// its length, so the heading rotates smoothly as the window slides
  /// across a bend instead of jumping straight over it.
  double _bearingAtDistance(double d) {
    const dist = ll.Distance(roundResult: false);
    final windowEnd = (d + _flightLookAheadMeters).clamp(0.0, _totalDistance);
    if (windowEnd <= d) return _lastBearing;

    double sx = 0, sy = 0;
    var pos = d;
    var idx = _segmentIndexAtDistance(d);
    while (pos < windowEnd - 1e-6 && idx < widget.geometry.length - 1) {
      final segEnd = _cumulativeDistance[idx + 1];
      final next = segEnd < windowEnd ? segEnd : windowEnd;
      if (next > pos) {
        final p1 = _positionAtDistance(pos);
        final p2 = _positionAtDistance(next);
        if (p1.latitude != p2.latitude || p1.longitude != p2.longitude) {
          final segLen = next - pos;
          final b = dist.bearing(p1, p2) * math.pi / 180;
          sx += math.cos(b) * segLen;
          sy += math.sin(b) * segLen;
        }
      }
      pos = next;
      idx++;
    }
    if (sx.abs() < 1e-9 && sy.abs() < 1e-9) return _lastBearing;
    final bearing = math.atan2(sy, sx) * 180 / math.pi;
    _lastBearing = (bearing + 360) % 360;
    return _lastBearing;
  }

  Future<void> _startFlight() async {
    final c = _controller;
    if (c == null || widget.geometry.length < 2 || _totalDistance <= 0) return;

    _flightController?.dispose();
    final seconds = (_totalDistance / _flightSpeedMps).clamp(10.0, 90.0);
    final controller = AnimationController(vsync: this, duration: Duration(milliseconds: (seconds * 1000).round()));
    _flightController = controller;

    final start = _positionAtDistance(0);
    await c.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(start.latitude, start.longitude),
        zoom: _flightZoom,
        tilt: _flightTilt,
        bearing: _bearingAtDistance(0),
      )),
      duration: const Duration(milliseconds: 700),
    );
    if (!mounted || _flightController != controller) return;

    controller.addListener(_onFlightTick);
    controller.addStatusListener(_onFlightStatus);
    setState(() {});
    controller.forward(from: 0);
  }

  void _onFlightTick() {
    final controller = _flightController;
    final c = _controller;
    if (controller == null || c == null) return;
    final now = DateTime.now();
    if (_lastCameraUpdate != null && now.difference(_lastCameraUpdate!) < _cameraUpdateInterval) return;
    _lastCameraUpdate = now;

    final d = controller.value * _totalDistance;
    final pos = _positionAtDistance(d);
    final bearing = _bearingAtDistance(d);
    c.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(pos.latitude, pos.longitude),
      zoom: _flightZoom,
      tilt: _flightTilt,
      bearing: bearing,
    )));
  }

  void _onFlightStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      if (mounted) setState(() {});
    }
  }

  void _stopFlight() {
    _flightController?.stop();
    setState(() {});
  }
}
