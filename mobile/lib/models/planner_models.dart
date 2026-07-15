import 'package:latlong2/latlong.dart';

/// A stop (waypoint) on a route: start, finish, or an intermediate point.
class Stop {
  int id;
  LatLng? latLng;
  String address;

  Stop({required this.id, this.latLng, this.address = ''});

  Map<String, dynamic> toJson() => latLng == null
      ? {}
      : {'lat': latLng!.latitude, 'lng': latLng!.longitude, 'address': address};

  static Stop fromJson(int id, Map<String, dynamic> j) => Stop(
        id: id,
        latLng: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        address: j['address'] as String? ?? '',
      );
}

/// A point of interest placed on the map (checkpoint, water, food, etc.).
class Poi {
  final int id;
  String type;
  LatLng latLng;
  String name;
  String note;
  int? checkpointNo; // computed: position along route among checkpoints

  Poi({
    required this.id,
    required this.type,
    required this.latLng,
    this.name = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'lat': latLng.latitude,
        'lng': latLng.longitude,
        'name': name,
        'note': note,
      };

  static Poi fromJson(int id, Map<String, dynamic> j) => Poi(
        id: id,
        type: j['type'] as String? ?? 'poi',
        latLng: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        name: j['name'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

/// A single route/variant: its own color, stops, and resolved road geometry.
class RouteTrack {
  int id;
  String name;
  int colorValue;
  List<Stop> stops;
  List<LatLng> geometry;
  double meters;

  RouteTrack({
    required this.id,
    required this.name,
    required this.colorValue,
    List<Stop>? stops,
    List<LatLng>? geometry,
    this.meters = 0,
  })  : stops = stops ?? [],
        geometry = geometry ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': '#${colorValue.toRadixString(16).substring(2)}',
        'stops': stops.where((s) => s.latLng != null).map((s) => s.toJson()).toList(),
      };
}

int parseHexColor(String? hex, int fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return int.tryParse(h, radix: 16) ?? fallback;
}
