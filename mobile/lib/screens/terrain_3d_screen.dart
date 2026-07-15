import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Pitched/rotated 3D terrain view of the route — port of the web app's
/// MapLibre-GL overlay. Style is embedded as a data: URI so no network
/// fetch of a style.json is needed before first paint.
class Terrain3DScreen extends StatefulWidget {
  final List<ll.LatLng> geometry;
  const Terrain3DScreen({super.key, required this.geometry});

  @override
  State<Terrain3DScreen> createState() => _Terrain3DScreenState();
}

class _Terrain3DScreenState extends State<Terrain3DScreen> {
  MapLibreMapController? _controller;

  static const _styleMap = {
    'version': 8,
    'sources': {
      'base': {
        'type': 'raster',
        'tiles': [
          'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          'https://b.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          'https://c.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
        ],
        'tileSize': 256,
        'attribution': '© OpenStreetMap © CARTO',
      },
      'dem': {
        'type': 'raster-dem',
        'tiles': ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
        'encoding': 'terrarium',
        'tileSize': 256,
        'maxzoom': 14,
      },
    },
    'layers': [
      {'id': 'base', 'type': 'raster', 'source': 'base'},
    ],
    'terrain': {'source': 'dem', 'exaggeration': 1.6},
  };

  static String get _styleDataUri => 'data:application/json;charset=utf-8,${Uri.encodeComponent(jsonEncode(_styleMap))}';

  @override
  Widget build(BuildContext context) {
    final mid = widget.geometry[widget.geometry.length ~/ 2];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _styleDataUri,
            initialCameraPosition: CameraPosition(
              target: LatLng(mid.latitude, mid.longitude),
              zoom: 13,
              tilt: 65,
              bearing: -17,
            ),
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            compassEnabled: true,
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: _onStyleLoaded,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: Material(
              color: const Color(0xFF141A22),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  child: Text('✕ Zamknij 3D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
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
}
