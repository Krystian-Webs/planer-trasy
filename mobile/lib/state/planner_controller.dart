import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planner_models.dart';
import '../services/export_service.dart';
import '../services/geo_service.dart';
import '../theme/app_theme.dart';

enum PlannerMode { route, poi }

/// Central app state — a direct port of the mutable globals in the web app's
/// <script> block (tracks/stops/pois/mode/snap/target/pace) into one
/// ChangeNotifier so widgets can listen and rebuild.
class PlannerController extends ChangeNotifier {
  PlannerController() {
    // Must assign to activeTrack (not just create the track): the `stops`
    // getter falls back to a fresh throwaway `[]` whenever activeTrack is
    // null, so ensureEndpoints()'s `while (stops.length < 2) stops.add(...)`
    // would add to a new list every iteration and spin forever — freezing
    // the isolate solid on the very first point placed on a fresh project.
    activeTrack = _newTrack();
    _loadAutosave();
  }

  // ---- identity ----
  int _idSeq = 1;
  int _trackSeq = 1;
  int _nextId() => _idSeq++;

  // ---- project ----
  String projectName = 'Moje wydarzenie';
  List<RouteTrack> tracks = [];
  RouteTrack? activeTrack;
  bool snap = true;
  bool showKm = false;
  PlannerMode mode = PlannerMode.route;
  String poiType = 'checkpoint';
  List<Poi> pois = [];

  // convenience: stops of the active track
  List<Stop> get stops => activeTrack?.stops ?? [];
  List<LatLng> get lastGeometry => activeTrack?.geometry ?? [];
  double get totalMeters => activeTrack?.meters ?? 0;
  double get sumMeters => tracks.fold(0.0, (a, t) => a + t.meters);

  // ---- target distance ----
  double? targetKm;
  LatLng? targetMarker;

  // ---- pace ----
  int paceSec = 360; // seconds per km

  // ---- elevation ----
  List<MapEntry<double, double>>? elevationProfile; // (distanceMeters, elevation)
  double elevAsc = 0, elevDesc = 0, elevMin = 0, elevMax = 0;
  bool elevationLoading = false;

  // ---- busy flags ----
  bool routing = false;
  bool proposing = false;

  String? lastToast;
  int _toastSeq = 0;
  int get toastSeq => _toastSeq;
  void toast(String msg) {
    lastToast = msg;
    _toastSeq++;
    notifyListeners();
  }

  Timer? _autosaveTimer;
  String _lastAutosaveJson = '';

  // ============================================================ undo =====
  static const _maxHistory = 40;
  final List<_Snapshot> _undoStack = [];
  final List<_Snapshot> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  RouteTrack _cloneTrack(RouteTrack t) => RouteTrack(
        id: t.id,
        name: t.name,
        colorValue: t.colorValue,
        stops: t.stops.map((s) => Stop(id: s.id, latLng: s.latLng, address: s.address)).toList(),
        geometry: List<LatLng>.from(t.geometry),
        meters: t.meters,
      );

  Poi _clonePoi(Poi p) => Poi(id: p.id, type: p.type, latLng: p.latLng, name: p.name, note: p.note)
    ..checkpointNo = p.checkpointNo;

  _Snapshot _snapshot() => _Snapshot(
        tracks: tracks.map(_cloneTrack).toList(),
        pois: pois.map(_clonePoi).toList(),
        activeTrackId: activeTrack?.id,
        targetKm: targetKm,
      );

  /// Call at the start of any user action that mutates tracks/stops/pois, so
  /// it becomes a single undoable step. Clears the redo stack — a fresh edit
  /// after undoing invalidates whatever was ahead.
  void _pushUndo() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restore(_Snapshot s) {
    tracks = s.tracks;
    pois = s.pois;
    activeTrack = tracks.firstWhere((t) => t.id == s.activeTrackId, orElse: () => tracks.isNotEmpty ? tracks.first : _newTrack());
    targetKm = s.targetKm;
    updateTargetMarker();
    _recomputeCheckpointNumbers();
    notifyListeners();
    _scheduleAutosave();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
    toast('Cofnięto.');
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
    toast('Ponowiono.');
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  // =========================================================== tracks ====
  RouteTrack _newTrack({String? name, int? color}) {
    final t = RouteTrack(
      id: _nextId(),
      name: name ?? 'Trasa $_trackSeq',
      colorValue: (color ?? kTrackColors[(_trackSeq - 1) % kTrackColors.length].toARGB32()),
    );
    _trackSeq++;
    tracks.add(t);
    return t;
  }

  void addTrack() {
    _pushUndo();
    final t = _newTrack();
    setActiveTrack(t.id);
    toast('Dodano nową trasę („${t.name}") — rysuj ją na mapie.');
  }

  void removeTrack(int id) {
    if (tracks.length <= 1) {
      toast('To jedyna trasa.');
      return;
    }
    _pushUndo();
    final wasActive = activeTrack?.id == id;
    tracks.removeWhere((t) => t.id == id);
    if (wasActive) {
      activeTrack = tracks.first;
    }
    toast('Usunięto trasę.');
    _rebuild();
  }

  /// Swaps the start and finish of the active track (and reverses any
  /// intermediate stops), so an out-and-back route can be flipped without
  /// re-placing every point.
  void reverseActiveTrack() {
    if (stops.length < 2) {
      toast('Potrzeba co najmniej startu i mety.');
      return;
    }
    _pushUndo();
    final reversed = stops.reversed.toList();
    stops
      ..clear()
      ..addAll(reversed);
    activeTrack!.geometry = activeTrack!.geometry.reversed.toList();
    notifyListeners();
    _scheduleAutosave();
    toast('Odwrócono kierunek trasy.');
  }

  void setActiveTrack(int id) {
    activeTrack = tracks.firstWhere((t) => t.id == id, orElse: () => tracks.first);
    notifyListeners();
  }

  void renameTrack(int id, String name) {
    tracks.firstWhere((t) => t.id == id).name = name;
    notifyListeners();
  }

  /// Imports a parsed GPX file: each `<trk>`/`<rte>` becomes a new route
  /// track using the raw recorded path as-is (not re-routed through OSRM,
  /// so the shape stays exactly what was recorded), and each `<wpt>`
  /// becomes a POI. Replaces the initial empty track if nothing was drawn
  /// on it yet, so importing into a fresh project doesn't leave a stray
  /// "Trasa 1" behind.
  Future<void> importGpx(ParsedGpx parsed) async {
    if (parsed.tracks.isEmpty && parsed.waypoints.isEmpty) {
      toast('Plik GPX nie zawiera trasy ani punktów.');
      return;
    }
    _pushUndo();
    if (tracks.length == 1 && !tracks.first.stops.any((s) => s.latLng != null)) {
      tracks.clear();
    }
    for (var i = 0; i < parsed.tracks.length; i++) {
      final pts = parsed.tracks[i];
      final t = RouteTrack(
        id: _nextId(),
        name: parsed.name ?? 'Trasa z GPX${parsed.tracks.length > 1 ? ' ${i + 1}' : ''}',
        colorValue: kTrackColors[(_trackSeq - 1) % kTrackColors.length].toARGB32(),
      );
      _trackSeq++;
      t.stops
        ..add(Stop(id: _nextId(), latLng: pts.first, address: 'Start (GPX)'))
        ..add(Stop(id: _nextId(), latLng: pts.last, address: 'Meta (GPX)'));
      t.geometry = pts;
      t.meters = totalLength(pts);
      tracks.add(t);
      activeTrack = t;
    }
    if (tracks.isEmpty) tracks.add(_newTrack());
    activeTrack ??= tracks.first;
    for (final w in parsed.waypoints) {
      pois.add(Poi(id: _nextId(), type: 'poi', latLng: w.latLng, name: w.name, note: w.desc));
    }
    _recomputeCheckpointNumbers();
    updateTargetMarker();
    notifyListeners();
    _scheduleAutosave();
    toast('Zaimportowano z GPX: ${parsed.tracks.length} tras, ${parsed.waypoints.length} punktów.');
  }

  // Find track whose geometry is near [ll] within [pxTolerance] — used to
  // let a map tap on an inactive track's line switch the active track,
  // mirroring the web app's click handler. Screen-space hit testing lives in
  // the map widget; this just exposes geometry.
  RouteTrack? nearestOtherTrack(LatLng ll, double Function(List<LatLng>) distanceFn) {
    RouteTrack? best;
    double bestD = double.infinity;
    for (final t in tracks) {
      if (t == activeTrack) continue;
      final d = distanceFn(t.geometry);
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    return bestD < double.infinity ? best : null;
  }

  // ============================================================ stops ====
  void ensureEndpoints() {
    // Guard against activeTrack being null: `stops` would otherwise fall
    // back to a fresh empty list on every access below, so this loop would
    // never observe its own additions and spin forever.
    activeTrack ??= tracks.isNotEmpty ? tracks.first : _newTrack();
    while (stops.length < 2) {
      stops.add(Stop(id: _nextId()));
    }
  }

  Stop addEmptyStop({int? atIndex}) {
    ensureEndpoints();
    final s = Stop(id: _nextId());
    if (atIndex != null) {
      stops.insert(atIndex, s);
    } else {
      stops.insert(stops.length - 1, s);
    }
    notifyListeners();
    return s;
  }

  void removeStop(int id) {
    _pushUndo();
    final isEnd = stops.isNotEmpty && (stops.first.id == id || stops.last.id == id);
    if (isEnd) {
      final s = stops.firstWhere((x) => x.id == id);
      s.latLng = null;
      s.address = '';
    } else {
      stops.removeWhere((x) => x.id == id);
    }
    _rebuild();
  }

  void moveStop(int index, int dir) {
    final j = index + dir;
    if (j < 0 || j >= stops.length) return;
    _pushUndo();
    final t = stops[index];
    stops[index] = stops[j];
    stops[j] = t;
    _rebuild();
  }

  Future<void> setStopLocation(Stop s, LatLng ll, {String? address}) async {
    _pushUndo();
    s.latLng = ll;
    s.address = address ?? await GeoService.reverseGeocode(ll);
    await _rebuild();
  }

  /// Place a point on the map in "route" mode: fills start, then finish,
  /// then inserts as new stop before finish — same priority as the web app.
  Future<void> placeRouteStop(LatLng ll, {String? address}) async {
    _pushUndo();
    ensureEndpoints();
    Stop s;
    if (stops.first.latLng == null) {
      s = stops.first;
    } else if (stops.last.latLng == null) {
      s = stops.last;
    } else {
      s = Stop(id: _nextId());
      stops.add(s);
    }
    s.latLng = ll;
    notifyListeners();
    s.address = address ?? await GeoService.reverseGeocode(ll);
    await _rebuild();
  }

  /// Insert a stop between two existing ones at the km position closest to [ll].
  Future<void> insertStopOnLine(LatLng ll) async {
    final k = kmAlong(lastGeometry, ll);
    if (k == null) {
      await placeRouteStop(ll);
      return;
    }
    _pushUndo();
    var insertIdx = -1;
    for (var i = 0; i < stops.length; i++) {
      if (stops[i].latLng == null) continue;
      final ki = kmAlong(lastGeometry, stops[i].latLng!);
      if (ki != null && ki > k + 0.0005) {
        insertIdx = i;
        break;
      }
    }
    if (insertIdx == -1) insertIdx = stops.length - 1;
    final s = Stop(id: _nextId(), latLng: ll);
    stops.insert(insertIdx, s);
    await _rebuild();
    s.address = await GeoService.reverseGeocode(ll);
    notifyListeners();
    toast('Dodano przystanek pomiędzy — kolejne przenumerowane.');
  }

  (String, int) stopLabel(int i) {
    if (stops.length <= 1 || i == 0) return ('Start', AppColors.good.toARGB32());
    if (i == stops.length - 1) return ('Meta', AppColors.ink.toARGB32());
    return ('Przystanek $i', AppColors.accent.toARGB32());
  }

  // ============================================================= POIs ====
  Poi addPoi(String type, LatLng ll, {String name = ''}) {
    _pushUndo();
    final p = Poi(id: _nextId(), type: type, latLng: ll, name: name);
    pois.add(p);
    _recomputeCheckpointNumbers();
    notifyListeners();
    _scheduleAutosave();
    return p;
  }

  void removePoi(int id) {
    _pushUndo();
    pois.removeWhere((p) => p.id == id);
    _recomputeCheckpointNumbers();
    notifyListeners();
    _scheduleAutosave();
  }

  void updatePoi(int id, {String? name, String? note}) {
    _pushUndo();
    final p = pois.firstWhere((x) => x.id == id);
    if (name != null) p.name = name;
    if (note != null) p.note = note;
    notifyListeners();
    _scheduleAutosave();
  }

  Future<void> movePoi(int id, LatLng ll) async {
    _pushUndo();
    final p = pois.firstWhere((x) => x.id == id);
    p.latLng = ll;
    _recomputeCheckpointNumbers();
    notifyListeners();
    _scheduleAutosave();
  }

  void clearPois() {
    if (pois.isEmpty) return;
    _pushUndo();
    pois.clear();
    notifyListeners();
    _scheduleAutosave();
  }

  void _recomputeCheckpointNumbers() {
    final cps = pois.where((p) => p.type == 'checkpoint').toList()
      ..sort((a, b) {
        final ka = kmAlong(lastGeometry, a.latLng) ?? 1e9;
        final kb = kmAlong(lastGeometry, b.latLng) ?? 1e9;
        return ka.compareTo(kb);
      });
    for (var i = 0; i < cps.length; i++) {
      cps[i].checkpointNo = i + 1;
    }
  }

  int get checkpointCount => pois.where((p) => p.type == 'checkpoint').length;

  // ============================================================ route ====
  Future<void> _rebuild() async {
    activeTrack ??= tracks.isNotEmpty ? tracks.first : _newTrack();
    final t = activeTrack!;
    final coords = t.stops.where((s) => s.latLng != null).map((s) => s.latLng!).toList();
    t.geometry = [];
    t.meters = 0;
    if (coords.isNotEmpty) {
      if (snap && coords.length >= 2) {
        routing = true;
        notifyListeners();
        final res = await GeoService.fetchRoute(coords);
        routing = false;
        if (res != null) {
          t.meters = res.meters;
          t.geometry = res.geometry;
        }
      }
      if (t.geometry.isEmpty) {
        t.geometry = coords;
        t.meters = totalLength(coords);
      }
    }
    _recomputeCheckpointNumbers();
    updateTargetMarker();
    notifyListeners();
    _scheduleAutosave();
  }

  Future<void> rebuildRoute() => _rebuild();

  void toggleSnap(bool v) {
    snap = v;
    _rebuild();
  }

  void toggleShowKm(bool v) {
    showKm = v;
    notifyListeners();
  }

  void setMode(PlannerMode m) {
    mode = m;
    notifyListeners();
  }

  void setPoiType(String t) {
    poiType = t;
    setMode(PlannerMode.poi);
  }

  // ---------------------------------------------------- target distance --
  void setTargetKm(double? km) {
    targetKm = km;
    updateTargetMarker();
    notifyListeners();
  }

  void updateTargetMarker() {
    if (targetKm == null || lastGeometry.length < 2) {
      targetMarker = null;
      return;
    }
    final target = targetKm! * 1000;
    if (totalMeters >= target) {
      targetMarker = pointAtMeters(lastGeometry, target);
    } else {
      targetMarker = null;
    }
  }

  Future<void> snapFinishToTarget() async {
    if (targetKm == null || lastGeometry.length < 2) return;
    final target = targetKm! * 1000;
    if (totalMeters < target) {
      toast('Trasa krótsza niż cel — najpierw wydłuż.');
      return;
    }
    final located = stops.where((s) => s.latLng != null).toList();
    if (located.length < 2) {
      toast('Potrzebny start i meta.');
      return;
    }
    final pt = pointAtMeters(lastGeometry, target);
    final last = located.last;
    last.latLng = pt;
    notifyListeners();
    last.address = await GeoService.reverseGeocode(pt);
    await _rebuild();
    toast('Meta dociągnięta blisko ${fmtKm(targetKm!)} km');
  }

  // ------------------------------------------------------- loop proposal --
  Future<void> proposeLoopRoute() async {
    ensureEndpoints();
    final start = stops.first.latLng;
    if (start == null) {
      toast('Najpierw ustaw Start — kliknij na mapie lub wpisz adres startu.');
      return;
    }
    final target = (targetKm ?? 5) * 1000;
    proposing = true;
    notifyListeners();
    const n = 6;
    final rot = math.Random().nextDouble() * 2 * math.pi;
    double radius = target / (2 * math.pi) * 0.8;
    List<LatLng>? bestPts;
    double bestMeters = double.infinity;
    for (var it = 0; it < 6; it++) {
      final pts = [for (var i = 0; i < n; i++) destPoint(start, radius, rot + 2 * math.pi * i / n)];
      final res = await GeoService.fetchRoute([start, ...pts, start]);
      if (res == null) break;
      if (bestPts == null || (res.meters - target).abs() < (bestMeters - target).abs()) {
        bestPts = pts;
        bestMeters = res.meters;
      }
      if ((res.meters - target).abs() <= target * 0.05) break;
      radius *= (target / res.meters).clamp(0.5, 1.8);
    }
    proposing = false;
    if (bestPts == null) {
      toast('Nie udało się ułożyć trasy — spróbuj ponownie lub przesuń start.');
      notifyListeners();
      return;
    }
    stops
      ..clear()
      ..add(Stop(id: _nextId(), latLng: start))
      ..addAll(bestPts.map((p) => Stop(id: _nextId(), latLng: p)))
      ..add(Stop(id: _nextId(), latLng: start));
    await _rebuild();
    toast('Propozycja: ${fmtKm(bestMeters / 1000)} km — przeciągnij punkty, by dopasować.');
  }

  // -------------------------------------------------- checkpoint distrib --
  void distributeCheckpoints(double everyKm) {
    if (lastGeometry.length < 2) {
      toast('Najpierw wyznacz trasę.');
      return;
    }
    final everyM = everyKm * 1000;
    if (everyM < 50) {
      toast('Podaj odstęp większy niż 0,05 km.');
      return;
    }
    var added = 0;
    for (var d = everyM; d < totalMeters; d += everyM) {
      addPoi('checkpoint', pointAtMeters(lastGeometry, d));
      added++;
    }
    toast(added > 0 ? 'Rozmieszczono $added punktów kontrolnych' : 'Trasa za krótka dla tego odstępu');
  }

  // ------------------------------------------------------------- pace ----
  void setPaceSec(int s) {
    paceSec = s;
    notifyListeners();
  }

  Duration? get estimatedDuration {
    final km = totalMeters / 1000;
    if (km <= 0) return null;
    return Duration(seconds: (km * paceSec).round());
  }

  // -------------------------------------------------------- elevation ----
  Future<void> computeElevation() async {
    if (lastGeometry.length < 2) {
      toast('Najpierw wyznacz trasę.');
      return;
    }
    elevationLoading = true;
    notifyListeners();
    try {
      final n = math.min(90, math.max(20, (totalMeters / 120).round()));
      final pts = <LatLng>[];
      final dists = <double>[];
      for (var i = 0; i <= n; i++) {
        final d = totalMeters * i / n;
        pts.add(pointAtMeters(lastGeometry, d));
        dists.add(d);
      }
      final e = await GeoService.fetchElevations(pts);
      if (e == null || e.isEmpty) throw Exception('no data');
      final sm = List<double>.generate(e.length, (i) {
        final a = math.max(0, i - 1);
        final b = math.min(e.length - 1, i + 1);
        return (e[a] + e[i] + e[b]) / 3;
      });
      double asc = 0, desc = 0;
      for (var i = 1; i < sm.length; i++) {
        final d = sm[i] - sm[i - 1];
        if (d > 0) {
          asc += d;
        } else {
          desc -= d;
        }
      }
      elevationProfile = [for (var i = 0; i < sm.length; i++) MapEntry(dists[i], sm[i])];
      elevAsc = asc;
      elevDesc = desc;
      elevMin = sm.reduce(math.min);
      elevMax = sm.reduce(math.max);
    } catch (_) {
      toast('Nie udało się pobrać wysokości — spróbuj ponownie.');
    } finally {
      elevationLoading = false;
      notifyListeners();
    }
  }

  // ============================================================ persist ==
  Map<String, dynamic> serialize() => {
        'v': 5,
        'name': projectName,
        'snap': snap,
        'activeTrack': activeTrack?.id,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'pois': pois.map((p) => p.toJson()).toList(),
      };

  Future<void> loadProject(Map<String, dynamic> d, {bool keepView = false}) async {
    _clearHistory();
    tracks = [];
    pois = [];
    _trackSeq = 1;
    projectName = d['name'] as String? ?? 'Wczytany projekt';
    if (d['snap'] is bool) snap = d['snap'] as bool;

    final trackDefs = (d['tracks'] as List?) ?? [];
    if (trackDefs.isEmpty) {
      // legacy single-track format
      final legacyStops = (d['stops'] ?? d['waypoints'] ?? []) as List;
      trackDefs.add({'name': 'Trasa 1', 'color': '#ff6b1a', 'stops': legacyStops});
    }
    for (final tdRaw in trackDefs) {
      final td = tdRaw as Map<String, dynamic>;
      final t = RouteTrack(
        id: (td['id'] as num?)?.toInt() ?? _nextId(),
        name: td['name'] as String? ?? 'Trasa $_trackSeq',
        colorValue: parseHexColor(td['color'] as String?, kTrackColors[0].toARGB32()),
      );
      if (td['id'] != null && (td['id'] as num).toInt() >= _idSeq) {
        _idSeq = (td['id'] as num).toInt() + 1;
      }
      _trackSeq++;
      for (final w in (td['stops'] as List? ?? [])) {
        final wm = w as Map<String, dynamic>;
        t.stops.add(Stop(
          id: _nextId(),
          latLng: LatLng((wm['lat'] as num).toDouble(), (wm['lng'] as num).toDouble()),
          address: wm['address'] as String? ?? '',
        ));
      }
      tracks.add(t);
    }
    if (tracks.isEmpty) tracks.add(_newTrack());

    for (final pRaw in (d['pois'] as List? ?? [])) {
      final pm = pRaw as Map<String, dynamic>;
      pois.add(Poi.fromJson(_nextId(), pm));
    }

    for (final t in tracks) {
      final coords = t.stops.where((s) => s.latLng != null).map((s) => s.latLng!).toList();
      t.geometry = [];
      t.meters = 0;
      if (coords.length >= 2) {
        if (snap) {
          final res = await GeoService.fetchRoute(coords);
          if (res != null) {
            t.meters = res.meters;
            t.geometry = res.geometry;
          }
        }
        if (t.geometry.isEmpty) {
          t.geometry = coords;
          t.meters = totalLength(coords);
        }
      }
    }
    final wantId = (d['activeTrack'] as num?)?.toInt();
    activeTrack = tracks.firstWhere((t) => t.id == wantId, orElse: () => tracks.first);
    _recomputeCheckpointNumbers();
    updateTargetMarker();
    notifyListeners();
    _scheduleAutosave();
  }

  void newProject() {
    _clearHistory();
    tracks = [];
    pois = [];
    _trackSeq = 1;
    projectName = 'Moje wydarzenie';
    activeTrack = _newTrack();
    targetKm = null;
    targetMarker = null;
    notifyListeners();
    _scheduleAutosave();
  }

  bool get hasContent => stops.any((s) => s.latLng != null) || pois.isNotEmpty;

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), _autosaveNow);
  }

  Future<void> _autosaveNow() async {
    try {
      final js = jsonEncode(serialize());
      if (js == _lastAutosaveJson) return;
      _lastAutosaveJson = js;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('planer_autosave', js);
    } catch (_) {}
  }

  Future<void> _loadAutosave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('planer_autosave');
      if (saved == null) return;
      final d = jsonDecode(saved) as Map<String, dynamic>;
      final tks = (d['tracks'] as List?) ?? [];
      final hasTrack = tks.any((t) => ((t as Map)['stops'] as List?)?.isNotEmpty == true);
      final hasPois = ((d['pois'] as List?) ?? []).isNotEmpty;
      if (hasTrack || hasPois) {
        await loadProject(d, keepView: true);
        toast('Przywrócono ostatni projekt z tego urządzenia.');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}

String fmtKm(double n) => (n).toStringAsFixed(2).replaceAll('.', ',');

/// A deep-copied snapshot of the editable project state, used by
/// [PlannerController]'s undo/redo stack. Kept in memory (not serialized)
/// so undo/redo is instant and never re-hits the routing API.
class _Snapshot {
  final List<RouteTrack> tracks;
  final List<Poi> pois;
  final int? activeTrackId;
  final double? targetKm;
  _Snapshot({required this.tracks, required this.pois, required this.activeTrackId, required this.targetKm});
}
