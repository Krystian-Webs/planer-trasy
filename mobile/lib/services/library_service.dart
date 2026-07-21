import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planner_models.dart';

/// One saved route in the local library — the full project JSON (for
/// reloading) plus lightweight, pre-computed metadata so the library list
/// can render instantly without re-parsing every entry's `data` blob.
class LibraryEntry {
  final String id;
  String name;
  final DateTime savedAt;
  final double distanceMeters;
  final int poiCount;
  final int trackCount;
  final List<List<double>> previewPoints; // downsampled [lat, lng] pairs
  final Map<String, dynamic> data;

  LibraryEntry({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.distanceMeters,
    required this.poiCount,
    required this.trackCount,
    required this.previewPoints,
    required this.data,
  });

  List<LatLng> get previewLatLngs => [for (final p in previewPoints) LatLng(p[0], p[1])];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'savedAt': savedAt.toIso8601String(),
        'distanceMeters': distanceMeters,
        'poiCount': poiCount,
        'trackCount': trackCount,
        'previewPoints': previewPoints,
        'data': data,
      };

  static LibraryEntry fromJson(Map<String, dynamic> j) => LibraryEntry(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Bez nazwy',
        savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
        distanceMeters: (j['distanceMeters'] as num?)?.toDouble() ?? 0,
        poiCount: (j['poiCount'] as num?)?.toInt() ?? 0,
        trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
        previewPoints: [
          for (final p in (j['previewPoints'] as List? ?? [])) [(p[0] as num).toDouble(), (p[1] as num).toDouble()],
        ],
        data: (j['data'] as Map).cast<String, dynamic>(),
      );
}

/// Local "My Routes" library — a list of saved projects distinct from the
/// single autosave slot, backed by SharedPreferences as one JSON array.
class LibraryService {
  static const _key = 'planer_library';

  static Future<List<LibraryEntry>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final arr = jsonDecode(raw) as List;
      final entries = arr.map((e) => LibraryEntry.fromJson((e as Map).cast<String, dynamic>())).toList();
      entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return entries;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeAll(List<LibraryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// Downsamples combined track geometry to ~[maxPoints] for a lightweight
  /// thumbnail — the full path isn't needed to sketch the route's shape.
  static List<List<double>> _preview(List<RouteTrack> tracks, {int maxPoints = 48}) {
    final all = <LatLng>[];
    for (final t in tracks) {
      all.addAll(t.geometry);
    }
    if (all.isEmpty) return [];
    final step = (all.length / maxPoints).ceil().clamp(1, all.length);
    return [for (var i = 0; i < all.length; i += step) [all[i].latitude, all[i].longitude]];
  }

  static Future<LibraryEntry> saveNew({
    required String name,
    required Map<String, dynamic> data,
    required List<RouteTrack> tracks,
    required int poiCount,
  }) async {
    final entries = await list();
    final entry = LibraryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      savedAt: DateTime.now(),
      distanceMeters: tracks.fold(0.0, (a, t) => a + t.meters),
      poiCount: poiCount,
      trackCount: tracks.length,
      previewPoints: _preview(tracks),
      data: data,
    );
    entries.insert(0, entry);
    await _writeAll(entries);
    return entry;
  }

  /// Overwrites an existing entry's data/stats in place (same id, new save).
  static Future<void> resave({
    required String id,
    required Map<String, dynamic> data,
    required List<RouteTrack> tracks,
    required int poiCount,
  }) async {
    final entries = await list();
    final i = entries.indexWhere((e) => e.id == id);
    if (i == -1) return;
    entries[i] = LibraryEntry(
      id: id,
      name: entries[i].name,
      savedAt: DateTime.now(),
      distanceMeters: tracks.fold(0.0, (a, t) => a + t.meters),
      poiCount: poiCount,
      trackCount: tracks.length,
      previewPoints: _preview(tracks),
      data: data,
    );
    await _writeAll(entries);
  }

  static Future<void> rename(String id, String name) async {
    final entries = await list();
    final i = entries.indexWhere((e) => e.id == id);
    if (i == -1) return;
    entries[i].name = name;
    await _writeAll(entries);
  }

  static Future<void> delete(String id) async {
    final entries = await list();
    entries.removeWhere((e) => e.id == id);
    await _writeAll(entries);
  }

  static Future<LibraryEntry> duplicate(String id) async {
    final entries = await list();
    final src = entries.firstWhere((e) => e.id == id);
    final copy = LibraryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '${src.name} (kopia)',
      savedAt: DateTime.now(),
      distanceMeters: src.distanceMeters,
      poiCount: src.poiCount,
      trackCount: src.trackCount,
      previewPoints: src.previewPoints,
      data: Map<String, dynamic>.from(src.data),
    );
    entries.insert(0, copy);
    await _writeAll(entries);
    return copy;
  }
}
