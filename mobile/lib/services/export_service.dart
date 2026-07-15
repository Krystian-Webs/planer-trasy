import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import '../models/planner_models.dart';
import '../theme/app_theme.dart';

/// A track (list of trkpt) and a waypoint parsed out of a GPX file.
class GpxWaypoint {
  final LatLng latLng;
  final String name;
  final String desc;
  GpxWaypoint({required this.latLng, this.name = '', this.desc = ''});
}

class ParsedGpx {
  final String? name;
  final List<List<LatLng>> tracks;
  final List<GpxWaypoint> waypoints;
  ParsedGpx({this.name, required this.tracks, required this.waypoints});
}

class ExportService {
  static String _slug(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
    return cleaned.isEmpty ? 'trasa' : cleaned;
  }

  static String _esc(String? s) => (s ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Builds the GPX XML — a direct port of exportGPX() from the web app.
  static String buildGpx({
    required String projectName,
    required List<RouteTrack> tracks,
    required List<Poi> pois,
  }) {
    final b = StringBuffer();
    b.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    b.write('<gpx version="1.1" creator="Planer Trasy" xmlns="http://www.topografix.com/GPX/1/1">\n');
    b.write('<metadata><name>${_esc(projectName.isEmpty ? 'Trasa' : projectName)}</name></metadata>\n');
    for (final p in pois) {
      final label = poiKindOf(p.type).label;
      b.write('<wpt lat="${p.latLng.latitude.toStringAsFixed(6)}" lon="${p.latLng.longitude.toStringAsFixed(6)}">');
      b.write('<name>${_esc(p.name.isEmpty ? label : p.name)}</name>');
      if (p.note.isNotEmpty) b.write('<desc>${_esc(p.note)}</desc>');
      b.write('<sym>${_esc(label)}</sym></wpt>\n');
    }
    for (final t in tracks) {
      if (t.geometry.length < 2) continue;
      b.write('<trk><name>${_esc(t.name)}</name><trkseg>');
      for (final c in t.geometry) {
        b.write('<trkpt lat="${c.latitude.toStringAsFixed(6)}" lon="${c.longitude.toStringAsFixed(6)}"/>');
      }
      b.write('</trkseg></trk>\n');
    }
    b.write('</gpx>');
    return b.toString();
  }

  static Future<void> shareGpx({
    required String projectName,
    required List<RouteTrack> tracks,
    required List<Poi> pois,
  }) async {
    final gpx = buildGpx(projectName: projectName, tracks: tracks, pois: pois);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_slug(projectName)}.gpx');
    await file.writeAsString(gpx);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Trasa GPX — $projectName'));
  }

  static Future<void> shareProjectJson(Map<String, dynamic> data, String projectName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_slug(projectName)}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'Projekt trasy — $projectName. Otwórz w Planerze Trasy przez „Wczytaj”.',
    ));
  }

  static Future<Map<String, dynamic>?> pickProjectJson() async {
    const typeGroup = XTypeGroup(label: 'Projekt trasy', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Opens a file picker for a .gpx file and returns its parsed content, or
  /// null if the user cancelled or the file couldn't be parsed.
  static Future<ParsedGpx?> pickGpx() async {
    const typeGroup = XTypeGroup(label: 'GPX', extensions: ['gpx'], mimeTypes: ['application/gpx+xml']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    final content = await file.readAsString();
    return parseGpx(content);
  }

  static double? _numAttr(XmlElement el, String name) {
    final v = el.getAttribute(name);
    return v == null ? null : double.tryParse(v);
  }

  static ParsedGpx parseGpx(String xmlText) {
    final doc = XmlDocument.parse(xmlText);
    final root = doc.rootElement;

    final name = root.findAllElements('metadata').expand((m) => m.findElements('name')).map((e) => e.innerText).firstOrNull ??
        root.findElements('name').map((e) => e.innerText).firstOrNull;

    final tracks = <List<LatLng>>[];
    for (final trk in root.findAllElements('trk')) {
      final pts = <LatLng>[];
      for (final trkpt in trk.findAllElements('trkpt')) {
        final lat = _numAttr(trkpt, 'lat');
        final lon = _numAttr(trkpt, 'lon');
        if (lat != null && lon != null) pts.add(LatLng(lat, lon));
      }
      if (pts.length >= 2) tracks.add(pts);
    }
    // A GPX with only a <rte> (route) instead of a <trk> — treat the same way.
    if (tracks.isEmpty) {
      for (final rte in root.findAllElements('rte')) {
        final pts = <LatLng>[];
        for (final rtept in rte.findAllElements('rtept')) {
          final lat = _numAttr(rtept, 'lat');
          final lon = _numAttr(rtept, 'lon');
          if (lat != null && lon != null) pts.add(LatLng(lat, lon));
        }
        if (pts.length >= 2) tracks.add(pts);
      }
    }

    final waypoints = <GpxWaypoint>[];
    for (final wpt in root.findAllElements('wpt')) {
      final lat = _numAttr(wpt, 'lat');
      final lon = _numAttr(wpt, 'lon');
      if (lat == null || lon == null) continue;
      final wName = wpt.findElements('name').map((e) => e.innerText).firstOrNull ?? '';
      final desc = wpt.findElements('desc').map((e) => e.innerText).firstOrNull ?? '';
      waypoints.add(GpxWaypoint(latLng: LatLng(lat, lon), name: wName, desc: desc));
    }

    return ParsedGpx(name: name, tracks: tracks, waypoints: waypoints);
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
