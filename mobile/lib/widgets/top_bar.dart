import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import '../services/geo_service.dart';
import '../state/planner_controller.dart';
import '../theme/app_theme.dart';

// Forces a dark frosted look regardless of the map tiles behind it — the
// default content-adaptive glass gets nearly invisible over the light
// Voyager basemap, unlike the web app's fixed-dark HUD.
const _hudGlassSettings = LiquidGlassSettings(
  glassColor: Color(0xCC141A22),
  thickness: 24,
  blur: 16,
);

class TopBar extends StatefulWidget {
  final MapController mapController;
  const TopBar({super.key, required this.mapController});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<GeocodeResult> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q, PlannerController c) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      final bounds = widget.mapController.camera.visibleBounds;
      final res = await GeoService.geocode(
        q,
        viewbox: GeoBounds(bounds.west, bounds.south, bounds.east, bounds.north),
      );
      if (!mounted) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    });
  }

  void _pick(GeocodeResult r, PlannerController c) {
    widget.mapController.move(r.latLng, 15);
    if (c.mode == PlannerMode.route) {
      c.placeRouteStop(r.latLng, address: r.main);
    } else {
      c.addPoi(c.poiType, r.latLng, name: r.main);
    }
    setState(() => _results = []);
    _searchCtrl.clear();
    _focusNode.unfocus();
    c.toast('Dodano: ${r.main}');
  }

  void _fitToRoute(PlannerController c) {
    final all = <LatLng>[];
    for (final t in c.tracks) {
      for (final s in t.stops) {
        if (s.latLng != null) all.add(s.latLng!);
      }
    }
    for (final p in c.pois) {
      all.add(p.latLng);
    }
    if (all.isEmpty) {
      c.toast('Brak punktów na trasie.');
      return;
    }
    if (all.length == 1) {
      widget.mapController.move(all.first, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints(all);
    widget.mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final sumKm = fmtKm(c.sumMeters / 1000);
    final hereKm = fmtKm(c.totalMeters / 1000);
    final distLabel = c.tracks.length > 1 ? '📏 Suma: $sumKm km (tu: $hereKm)' : '📏 Trasa: $hereKm km';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassSegmentedControl(
              segments: const [
                GlassSegment(label: '✏️ Rysuj trasę'),
                GlassSegment(label: '📍 Stawiaj punkty'),
              ],
              selectedIndex: c.mode == PlannerMode.route ? 0 : 1,
              onSegmentSelected: (i) => c.setMode(i == 0 ? PlannerMode.route : PlannerMode.poi),
              height: 44,
              // Full pill (radius = height / 2) to match the search field
              // and the pill buttons below — the 16px library default reads
              // as a plain rounded rect next to those fully-rounded shapes.
              borderRadius: 22,
              settings: _hudGlassSettings,
              useOwnLayer: true,
              quality: GlassQuality.standard,
              backgroundColor: const Color(0xE0141A22),
              indicatorColor: AppColors.accent,
              selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              unselectedTextStyle: const TextStyle(color: AppColors.inkDim, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GlassTextField.search(
              controller: _searchCtrl,
              focusNode: _focusNode,
              placeholder: c.mode == PlannerMode.route ? 'Szukaj miejsca — start / meta…' : 'Szukaj miejsca, by postawić punkt…',
              onChanged: (q) => _onSearchChanged(q, c),
              height: 46,
              settings: _hudGlassSettings,
              useOwnLayer: true,
              quality: GlassQuality.standard,
              textStyle: const TextStyle(color: AppColors.ink, fontSize: 15),
              placeholderStyle: const TextStyle(color: AppColors.inkDim, fontSize: 15),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text('Szukam…', style: TextStyle(color: AppColors.inkDim, fontSize: 11)),
              ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: AppColors.panelSolid.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.lineSoft),
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, color: AppColors.accent, size: 18),
                      title: Text(r.main, style: const TextStyle(color: AppColors.ink, fontSize: 12.5)),
                      subtitle: r.rest.isEmpty
                          ? null
                          : Text(r.rest, style: const TextStyle(color: AppColors.inkDim, fontSize: 10.5)),
                      onTap: () => _pick(r, c),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(child: _Pill(text: distLabel)),
                const SizedBox(width: 6),
                _Pill(text: '🔍 Pokaż całą trasę', onTap: () => _fitToRoute(c)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _Pill({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(99),
          boxShadow: const [BoxShadow(color: Color(0x59FF6B1A), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
