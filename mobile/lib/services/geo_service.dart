import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodeResult {
  final String main;
  final String rest;
  final LatLng latLng;
  GeocodeResult(this.main, this.rest, this.latLng);
}

class RouteResult {
  final double meters;
  final List<LatLng> geometry;
  RouteResult(this.meters, this.geometry);
}

/// Lightweight bounds box, decoupled from any map-widget package.
class GeoBounds {
  final double west, south, east, north;
  const GeoBounds(this.west, this.south, this.east, this.north);
}

const Distance _dist = Distance();

/// Great-circle distance in meters, matching the web app's haversine().
double haversine(LatLng a, LatLng b) => _dist(a, b);

class GeoService {
  static final http.Client _client = http.Client();
  static const _headers = {'User-Agent': 'PlanerTrasy-iOS/1.0'};

  static Future<List<GeocodeResult>> geocode(String query, {GeoBounds? viewbox}) async {
    final params = {
      'format': 'jsonv2',
      'limit': '6',
      'accept-language': 'pl',
      'q': query,
    };
    if (viewbox != null) {
      params['viewbox'] =
          '${viewbox.west},${viewbox.north},${viewbox.east},${viewbox.south}';
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final r = await _client.get(uri, headers: _headers);
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body) as List;
    return list.map((it) {
      final parts = (it['display_name'] as String).split(', ');
      final main = parts.isNotEmpty ? parts.removeAt(0) : '';
      return GeocodeResult(
        main,
        parts.join(', '),
        LatLng(double.parse(it['lat']), double.parse(it['lon'])),
      );
    }).toList();
  }

  static Future<String> reverseGeocode(LatLng ll) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'accept-language': 'pl',
        'lat': ll.latitude.toString(),
        'lon': ll.longitude.toString(),
      });
      final r = await _client.get(uri, headers: _headers);
      if (r.statusCode != 200) return '';
      final j = jsonDecode(r.body);
      final name = j['display_name'] as String?;
      if (name == null) return '';
      return name.split(', ').take(2).join(', ');
    } catch (_) {
      return '';
    }
  }

  static Future<RouteResult?> fetchRoute(List<LatLng> coords) async {
    final pairs = coords.map((c) => '${c.longitude},${c.latitude}').join(';');
    final providers = [
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot/$pairs?overview=full&geometries=geojson',
      'https://router.project-osrm.org/route/v1/driving/$pairs?overview=full&geometries=geojson',
      'https://routing.openstreetmap.de/routed-bike/route/v1/bike/$pairs?overview=full&geometries=geojson',
    ];
    for (final url in providers) {
      try {
        final r = await _client.get(Uri.parse(url));
        if (r.statusCode != 200) continue;
        final j = jsonDecode(r.body);
        final routes = j['routes'] as List?;
        if (routes == null || routes.isEmpty) continue;
        final geom = routes[0]['geometry']['coordinates'] as List;
        if (geom.length <= 1) continue;
        return RouteResult(
          (routes[0]['distance'] as num).toDouble(),
          geom.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList(),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Street names along the route, in order, deduplicated — for the PNG poster.
  /// Not used in v1 but kept small/cheap in case needed later.
  static Future<List<String>> fetchStreetNames(List<LatLng> pts) async {
    if (pts.length < 2) return [];
    final pairs = pts.map((c) => '${c.longitude},${c.latitude}').join(';');
    final urls = [
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot/$pairs?overview=false&steps=true',
      'https://router.project-osrm.org/route/v1/driving/$pairs?overview=false&steps=true',
    ];
    for (final u in urls) {
      try {
        final r = await _client.get(Uri.parse(u));
        if (r.statusCode != 200) continue;
        final j = jsonDecode(r.body);
        final routes = j['routes'] as List?;
        if (routes == null || routes.isEmpty) continue;
        final seen = <String>{};
        final ordered = <String>[];
        for (final leg in (routes[0]['legs'] as List)) {
          for (final step in (leg['steps'] as List)) {
            final nm = (step['name'] as String? ?? '').trim();
            if (nm.isNotEmpty && seen.add(nm)) ordered.add(nm);
          }
        }
        return ordered;
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  static Future<List<double>?> fetchElevations(List<LatLng> pts) async {
    try {
      final lats = pts.map((p) => p.latitude.toStringAsFixed(5)).join(',');
      final lngs = pts.map((p) => p.longitude.toStringAsFixed(5)).join(',');
      final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
        'latitude': lats,
        'longitude': lngs,
      });
      final r = await _client.get(uri);
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      final e = (j['elevation'] as List?)?.map((v) => (v as num).toDouble()).toList();
      if (e == null || e.isEmpty) return null;
      return e;
    } catch (_) {
      return null;
    }
  }
}

/// Distance in km along a polyline geometry closest to [latLng]; null if geometry too short.
double? kmAlong(List<LatLng> geometry, LatLng latLng) {
  if (geometry.length < 2) return null;
  double best = double.infinity;
  double bestDist = 0;
  double acc = 0;
  for (var i = 1; i < geometry.length; i++) {
    final a = geometry[i - 1];
    final b = geometry[i];
    final seg = haversine(a, b);
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final denom = (dx * dx + dy * dy);
    var t = denom == 0
        ? 0.0
        : (((latLng.longitude - a.longitude) * dx + (latLng.latitude - a.latitude) * dy) / denom);
    t = t.clamp(0.0, 1.0);
    final proj = LatLng(a.latitude + t * dy, a.longitude + t * dx);
    final d = haversine(latLng, proj);
    if (d < best) {
      best = d;
      bestDist = acc + seg * t;
    }
    acc += seg;
  }
  return bestDist / 1000;
}

/// Point at [targetMeters] along the route geometry (clamped to the end).
LatLng pointAtMeters(List<LatLng> geometry, double targetMeters) {
  double acc = 0;
  for (var i = 1; i < geometry.length; i++) {
    final a = geometry[i - 1];
    final b = geometry[i];
    final seg = haversine(a, b);
    if (acc + seg >= targetMeters) {
      final t = seg == 0 ? 0.0 : (targetMeters - acc) / seg;
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
    }
    acc += seg;
  }
  final last = geometry.last;
  return last;
}

/// Destination point given a start, distance in meters and bearing in radians.
LatLng destPoint(LatLng c, double dist, double brg) {
  const r = 6371000.0;
  final lat1 = c.latitude * math.pi / 180;
  final lng1 = c.longitude * math.pi / 180;
  final dr = dist / r;
  final lat2 = math.asin(math.sin(lat1) * math.cos(dr) + math.cos(lat1) * math.sin(dr) * math.cos(brg));
  final lng2 = lng1 +
      math.atan2(math.sin(brg) * math.sin(dr) * math.cos(lat1), math.cos(dr) - math.sin(lat1) * math.sin(lat2));
  return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
}

double totalLength(List<LatLng> geometry) {
  double m = 0;
  for (var i = 1; i < geometry.length; i++) {
    m += haversine(geometry[i - 1], geometry[i]);
  }
  return m;
}
