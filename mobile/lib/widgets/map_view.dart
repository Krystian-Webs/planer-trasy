import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/planner_models.dart';
import '../services/geo_service.dart';
import '../services/location_service.dart';
import '../state/planner_controller.dart';
import '../theme/app_theme.dart';
import 'marker_icons.dart';
import 'poi_type_sheet.dart';

enum BaseLayer { voyager, osm, satellite }

class MapView extends StatefulWidget {
  final MapController mapController;
  // Lets the host screen react when the user switches draw/place mode from
  // the floating pill (e.g. to reveal the matching sheet tab) — see
  // PlannerScreen for why entering "place points" mode specifically needs
  // this and entering "draw route" mode doesn't.
  final ValueChanged<PlannerMode>? onModeChanged;
  const MapView({super.key, required this.mapController, this.onModeChanged});

  @override
  State<MapView> createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  final GlobalKey _boxKey = GlobalKey();
  BaseLayer _base = BaseLayer.voyager;

  // local (non-committed) drag state — kept out of PlannerController so we
  // don't trigger a route rebuild + network call on every pixel of movement.
  int? _draggingStopId;
  LatLng? _draggingStopPos;
  int? _draggingPoiId;
  LatLng? _draggingPoiPos;

  LatLng? _myLocation;
  StreamSubscription<LatLng>? _locSub;
  bool _locating = false;
  bool _hintDismissed = false;

  bool get _isDragging => _draggingStopId != null || _draggingPoiId != null;

  @override
  void dispose() {
    _locSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleMyLocation() async {
    if (_locSub != null) {
      await _locSub!.cancel();
      _locSub = null;
      setState(() => _myLocation = null);
      return;
    }
    setState(() => _locating = true);
    final ok = await LocationService.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      setState(() => _locating = false);
      if (context.mounted) context.read<PlannerController>().toast('Brak dostępu do lokalizacji — sprawdź ustawienia.');
      return;
    }
    var firstFix = true;
    _locSub = LocationService.positionStream().listen((ll) {
      if (!mounted) return;
      setState(() {
        _myLocation = ll;
        _locating = false;
      });
      if (firstFix) {
        firstFix = false;
        widget.mapController.move(ll, 15);
      }
    });
  }

  LatLng? _hitTestToLatLng(Offset globalPos) {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    if (local.dx < 0 || local.dy < 0 || local.dx > box.size.width || local.dy > box.size.height) {
      return null;
    }
    return widget.mapController.camera.offsetToCrs(local);
  }

  double _pxDistToGeom(Offset tapRelative, List<LatLng> geom) {
    if (geom.length < 2) return double.infinity;
    final camera = widget.mapController.camera;
    double best = double.infinity;
    for (var i = 1; i < geom.length; i++) {
      final a = camera.latLngToScreenOffset(geom[i - 1]);
      final b = camera.latLngToScreenOffset(geom[i]);
      final d = _pxPointToSegment(tapRelative, a, b);
      if (d < best) best = d;
    }
    return best;
  }

  double _pxPointToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = dx * dx + dy * dy;
    var t = len == 0 ? 0.0 : (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / len);
    t = t.clamp(0.0, 1.0);
    final qx = a.dx + t * dx, qy = a.dy + t * dy;
    return (p - Offset(qx, qy)).distance;
  }

  void _onMapTap(PlannerController c, TapPosition tapPosition, LatLng ll) async {
    if (_isDragging) return;
    if (c.mode == PlannerMode.route) {
      RouteTrack? near;
      double nd = 18;
      for (final t in c.tracks) {
        if (t == c.activeTrack) continue;
        final d = _pxDistToGeom(tapPosition.relative ?? tapPosition.global, t.geometry);
        if (d < nd) {
          nd = d;
          near = t;
        }
      }
      if (near != null) {
        c.setActiveTrack(near.id);
        c.toast('Przełączono na: ${near.name}');
        return;
      }
      final locatedCount = c.stops.where((s) => s.latLng != null).length;
      HapticFeedback.lightImpact();
      if (locatedCount >= 2 && _pxDistToGeom(tapPosition.relative ?? tapPosition.global, c.lastGeometry) < 18) {
        await c.insertStopOnLine(ll);
      } else {
        await c.placeRouteStop(ll);
      }
    } else {
      HapticFeedback.lightImpact();
      showPoiTypeSheet(context, onPick: (type) => c.addPoi(type, ll));
    }
  }

  void _startStopDrag(Stop s) {
    HapticFeedback.selectionClick();
    setState(() {
      _draggingStopId = s.id;
      _draggingStopPos = s.latLng;
    });
  }

  void _moveStopDrag(LatLng ll) {
    if (_draggingStopId == null) return;
    setState(() => _draggingStopPos = ll);
  }

  void _endStopDrag(PlannerController c) {
    final id = _draggingStopId;
    final pos = _draggingStopPos;
    setState(() {
      _draggingStopId = null;
      _draggingStopPos = null;
    });
    if (id == null || pos == null) return;
    final stop = c.stops.where((s) => s.id == id).cast<Stop?>().firstOrNull;
    if (stop != null) c.setStopLocation(stop, pos);
  }

  void _startPoiDrag(Poi p) {
    HapticFeedback.selectionClick();
    setState(() {
      _draggingPoiId = p.id;
      _draggingPoiPos = p.latLng;
    });
  }

  void _movePoiDrag(LatLng ll) {
    if (_draggingPoiId == null) return;
    setState(() => _draggingPoiPos = ll);
  }

  void _endPoiDrag(PlannerController c) {
    final id = _draggingPoiId;
    final pos = _draggingPoiPos;
    setState(() {
      _draggingPoiId = null;
      _draggingPoiPos = null;
    });
    if (id == null || pos == null) return;
    c.movePoi(id, pos);
  }

  Widget _draggableMarkerChild({
    required PlannerController c,
    required Widget child,
    required VoidCallback onStart,
    required ValueChanged<LatLng> onMove,
    required VoidCallback onEnd,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onStart(),
      onPointerMove: (e) {
        final ll = _hitTestToLatLng(e.position);
        if (ll != null) onMove(ll);
      },
      onPointerUp: (_) => onEnd(),
      onPointerCancel: (_) => onEnd(),
      child: child,
    );
  }

  void _zoomBy(double delta) {
    HapticFeedback.selectionClick();
    final camera = widget.mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(2.0, 19.0);
    widget.mapController.move(camera.center, newZoom);
  }

  /// One [Polyline] per track normally; when grade coloring is on, the
  /// active track is instead split into a short segment per elevation
  /// sample, each tinted by that segment's climb/descent steepness.
  List<Polyline> _buildPolylines(PlannerController c) {
    final profile = c.elevationProfile;
    final activeGeom = c.activeTrack?.geometry;
    final gradeSegments = c.showGradeColor && profile != null && profile.length >= 2 && activeGeom != null && activeGeom.length >= 2
        ? _gradeColoredSegments(activeGeom, profile)
        : null;
    return [
      for (final t in c.tracks)
        if (t.geometry.length >= 2)
          if (gradeSegments != null && t == c.activeTrack)
            ...gradeSegments
          else
            Polyline(
              points: t.geometry,
              color: Color(t.colorValue).withValues(alpha: t == c.activeTrack ? 0.95 : 0.55),
              strokeWidth: t == c.activeTrack ? 6 : 4,
            ),
    ];
  }

  List<Polyline> _gradeColoredSegments(List<LatLng> geometry, List<MapEntry<double, double>> profile) {
    final segs = <Polyline>[];
    for (var i = 1; i < profile.length; i++) {
      final d0 = profile[i - 1].key, d1 = profile[i].key;
      final dist = d1 - d0;
      if (dist <= 0) continue;
      final grade = (profile[i].value - profile[i - 1].value) / dist * 100;
      segs.add(Polyline(
        points: [pointAtMeters(geometry, d0), pointAtMeters(geometry, d1)],
        color: AppColors.gradeColor(grade),
        strokeWidth: 6,
      ));
    }
    return segs;
  }

  String _tileUrl(BaseLayer b) {
    switch (b) {
      case BaseLayer.voyager:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case BaseLayer.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case BaseLayer.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();

    final stopMarkers = <Marker>[];
    var n = 0;
    for (var i = 0; i < c.stops.length; i++) {
      final s = c.stops[i];
      final pos = (s.id == _draggingStopId) ? _draggingStopPos : s.latLng;
      if (pos == null) continue;
      n++;
      final (label, _) = c.stopLabel(i);
      final short = label == 'Start' ? 'S' : (label == 'Meta' ? 'M' : '$n');
      stopMarkers.add(Marker(
        point: pos,
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _confirmDeleteStop(context, c, s),
          child: _draggableMarkerChild(
            c: c,
            onStart: () => _startStopDrag(s),
            onMove: _moveStopDrag,
            onEnd: () => _endStopDrag(c),
            child: StopMarkerIcon(label: short, color: Colors.orange, dragging: s.id == _draggingStopId),
          ),
        ),
      ));
    }

    final poiMarkers = <Marker>[
      for (final p in c.pois)
        Marker(
          point: p.id == _draggingPoiId ? (_draggingPoiPos ?? p.latLng) : p.latLng,
          width: 38,
          height: 38,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => showPoiEditSheet(context, controller: c, poi: p),
            child: _draggableMarkerChild(
              c: c,
              onStart: () => _startPoiDrag(p),
              onMove: _movePoiDrag,
              onEnd: () => _endPoiDrag(c),
              child: PoiMarkerIcon(
                kind: poiKindOf(p.type),
                badge: p.type == 'checkpoint' ? p.checkpointNo : null,
                dragging: p.id == _draggingPoiId,
              ),
            ),
          ),
        ),
    ];

    final kmMarkers = <Marker>[];
    if (c.showKm && c.lastGeometry.length >= 2) {
      final totalKm = (c.totalMeters / 1000).floor();
      for (var km = 1; km < totalKm + 1 && km * 1000 < c.totalMeters; km++) {
        kmMarkers.add(Marker(
          point: pointAtMeters(c.lastGeometry, km * 1000.0),
          width: 44,
          height: 22,
          child: KmLabel(km: km),
        ));
      }
    }

    final targetMarkers = <Marker>[];
    if (c.targetMarker != null && c.targetKm != null) {
      targetMarkers.add(Marker(
        point: c.targetMarker!,
        width: 90,
        height: 34,
        alignment: Alignment.bottomCenter,
        child: TargetFlagMarker(label: '${fmtKm(c.targetKm!)} km'),
      ));
    }

    // Float the overlay buttons just above the bottom sheet's default "half"
    // height (see GlassBottomSheet.initialChildSize) rather than a fixed
    // pixel offset, so they aren't hidden behind the panel on first launch.
    final panelClearance = MediaQuery.sizeOf(context).height * 0.48 + 14;

    // GlassScaffold's `background` slot sits outside its internal Scaffold's
    // Material subtree, so InkWell/IconButton here need their own ancestor.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
      key: _boxKey,
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: const LatLng(52.2297, 21.0122),
            initialZoom: 13,
            interactionOptions: InteractionOptions(
              flags: _isDragging ? InteractiveFlag.none : InteractiveFlag.all,
            ),
            onTap: (pos, ll) => _onMapTap(c, pos, ll),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl(_base),
              subdomains: _base == BaseLayer.voyager ? const ['a', 'b', 'c', 'd'] : const [],
              userAgentPackageName: 'com.planertrasy.mobile',
            ),
            PolylineLayer(polylines: _buildPolylines(c)),
            MarkerLayer(markers: kmMarkers),
            MarkerLayer(markers: targetMarkers),
            MarkerLayer(markers: stopMarkers),
            MarkerLayer(markers: poiMarkers),
            if (_myLocation != null)
              MarkerLayer(markers: [
                Marker(point: _myLocation!, width: 60, height: 60, child: const MyLocationMarker()),
              ]),
          ],
        ),
        // Left cluster: mode toggle above undo/redo — grouped in a Column
        // like the right cluster, so spacing stays consistent.
        Positioned(
          left: 10,
          bottom: panelClearance,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModePill(
                mode: c.mode,
                onChanged: (m) {
                  c.setMode(m);
                  widget.onModeChanged?.call(m);
                },
              ),
              const SizedBox(height: 10),
              _ButtonPill(
                items: [
                  _PillItem(icon: Icons.undo, onTap: c.canUndo ? c.undo : null, tooltip: 'Cofnij'),
                  _PillItem(icon: Icons.redo, onTap: c.canRedo ? c.redo : null, tooltip: 'Ponów'),
                ],
              ),
            ],
          ),
        ),
        // Right cluster: zoom, my-location, layer picker — grouped with
        // consistent spacing (Column, not manually-stacked bottom offsets)
        // so they can never drift into overlapping each other again.
        Positioned(
          right: 10,
          bottom: panelClearance,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ButtonPill(
                items: [
                  _PillItem(icon: Icons.add, onTap: () => _zoomBy(1), tooltip: 'Przybliż'),
                  _PillItem(icon: Icons.remove, onTap: () => _zoomBy(-1), tooltip: 'Oddal'),
                ],
              ),
              const SizedBox(height: 10),
              _RoundIconButton(
                icon: _myLocation != null ? Icons.my_location : Icons.location_searching,
                active: _myLocation != null,
                loading: _locating,
                onTap: _toggleMyLocation,
              ),
              const SizedBox(height: 10),
              _LayerPickerButton(
                current: _base,
                onChanged: (b) => setState(() => _base = b),
              ),
            ],
          ),
        ),
        if (!_hintDismissed && c.stops.every((s) => s.latLng == null) && c.pois.isEmpty)
          Align(
            alignment: const Alignment(0, -0.32),
            child: _EmptyStateHint(
              mode: c.mode,
              onDismiss: () => setState(() => _hintDismissed = true),
            ),
          ),
      ],
      ),
    );
  }

  void _confirmDeleteStop(BuildContext context, PlannerController c, Stop s) {
    final idx = c.stops.indexOf(s);
    final (label, _) = c.stopLabel(idx);
    showStopActionSheet(context, title: label, onDelete: () {
      c.removeStop(s.id);
      c.toast('Usunięto punkt — trasa przeliczona.');
    });
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _layerLabel(BaseLayer b) => switch (b) {
      BaseLayer.voyager => 'Standardowa',
      BaseLayer.osm => 'OpenStreetMap',
      BaseLayer.satellite => 'Satelitarna',
    };

IconData _layerIcon(BaseLayer b) => switch (b) {
      BaseLayer.voyager => Icons.map_outlined,
      BaseLayer.osm => Icons.public,
      BaseLayer.satellite => Icons.satellite_alt_outlined,
    };

/// Round button showing the active base-layer icon; tapping it opens a
/// themed popup menu to switch layers — replaces a permanently-visible
/// 3-button stack that ate vertical space and could overlap its neighbours.
class _LayerPickerButton extends StatelessWidget {
  final BaseLayer current;
  final ValueChanged<BaseLayer> onChanged;
  const _LayerPickerButton({required this.current, required this.onChanged});

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    final button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.topLeft(Offset.zero) - const Offset(180, 0), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final result = await showMenu<BaseLayer>(
      context: context,
      position: position,
      color: AppColors.panelSolid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.line)),
      items: [
        for (final b in BaseLayer.values)
          PopupMenuItem(
            value: b,
            height: 44,
            child: Row(
              children: [
                Icon(_layerIcon(b), size: 18, color: b == current ? AppColors.accent : AppColors.inkDim),
                const SizedBox(width: 10),
                Text(_layerLabel(b),
                    style: TextStyle(
                      color: b == current ? AppColors.accent : AppColors.ink,
                      fontWeight: b == current ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    )),
                if (b == current) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: AppColors.accent),
                ],
              ],
            ),
          ),
      ],
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => _RoundIconButton(
        icon: _layerIcon(current),
        onTap: () => _open(context),
      ),
    );
  }
}

/// Floating "Trasa" / "Punkty" mode switch — was a full-width segmented
/// control under the search bar, then a wide two-line pill; now icon-over-
/// label like a compact tab, same 44px width as the pills below it so the
/// whole left cluster reads as one narrow column instead of eating map width.
class _ModePill extends StatelessWidget {
  final PlannerMode mode;
  final ValueChanged<PlannerMode> onChanged;
  const _ModePill({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // No border here (a border ring + clipped content don't align cleanly
    // at small radii, and it read as a heavy frame anyway) — just a
    // rounded, shadowed clip, borderless like the rest of the floating
    // map controls.
    return Container(
      width: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: AppColors.panelSolid.withValues(alpha: 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeButton(icon: Icons.edit_location_alt_outlined, label: 'Trasa', selected: mode == PlannerMode.route, onTap: () {
              HapticFeedback.selectionClick();
              onChanged(PlannerMode.route);
            }),
            const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
            _ModeButton(icon: Icons.location_on_outlined, label: 'Punkty', selected: mode == PlannerMode.poi, onTap: () {
              HapticFeedback.selectionClick();
              onChanged(PlannerMode.poi);
            }),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.inkDim;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(gradient: selected ? AppColors.accentGradient : null),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, fontSize: 8.5, letterSpacing: .1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillItem {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  const _PillItem({required this.icon, required this.onTap, required this.tooltip});
}

/// Two related actions (zoom in/out, undo/redo) grouped into one rounded
/// pill instead of two separate floating circles — reads as a single
/// control, takes less space, and can't drift into overlapping a neighbour.
class _ButtonPill extends StatelessWidget {
  final List<_PillItem> items;
  const _ButtonPill({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: AppColors.panelSolid.withValues(alpha: 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
              _PillButton(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final _PillItem item;
  const _PillButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final disabled = item.onTap == null;
    return Tooltip(
      message: item.tooltip,
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: InkWell(
          onTap: item.onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(item.icon, size: 20, color: AppColors.inkDim)),
        ),
      ),
    );
  }
}

/// Standalone round map-overlay button, used for "center on me" and undo/redo.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool loading;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, required this.onTap, this.active = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.panelSolid.withValues(alpha: 0.92),
          border: active ? Border.all(color: AppColors.accent, width: 1.5) : null,
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              )
            : Icon(icon, size: 20, color: active ? AppColors.accent : AppColors.inkDim),
      ),
      ),
    );
  }
}

/// Friendly first-look tip shown over an empty map, pointing new users at
/// the two ways to place the first point — dismisses for the rest of the
/// session once tapped away or once a point is placed.
class _EmptyStateHint extends StatelessWidget {
  final PlannerMode mode;
  final VoidCallback onDismiss;
  const _EmptyStateHint({required this.mode, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final text = mode == PlannerMode.route
        ? 'Dotknij mapy, aby ustawić start trasy, albo wyszukaj adres u góry.'
        : 'Wybierz typ punktu w zakładce „Punkty”, potem dotknij mapy.';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.scale(scale: 0.94 + 0.06 * t, child: child)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.panelSolid.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('👋', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: const TextStyle(color: AppColors.ink, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w500)),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8, top: 1),
                  child: Icon(Icons.close, size: 16, color: AppColors.inkDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

