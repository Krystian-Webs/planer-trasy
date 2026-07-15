import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/planner_models.dart';
import '../../services/geo_service.dart';
import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import 'ui_kit.dart';

class StopsSection extends StatelessWidget {
  const StopsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final stops = c.stops;
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Trasa — wpisz adresy'),
          for (var i = 0; i < stops.length; i++)
            _StopRow(
              key: ValueKey(stops[i].id),
              stop: stops[i],
              index: i,
              isFirst: i == 0,
              isLast: i == stops.length - 1,
            ),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: '＋ Dodaj przystanek',
                  onTap: () => c.addEmptyStop(),
                ),
              ),
              const SizedBox(width: 8),
              ActionButton(
                label: '⇅ Odwróć',
                compact: true,
                onTap: stops.where((s) => s.latLng != null).length >= 2 ? c.reverseActiveTrack : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchRow(
            title: 'Przyciągaj do ulic',
            subtitle: 'Wyłącz dla linii prostej',
            value: c.snap,
            onChanged: c.toggleSnap,
          ),
          const HintText('Wpisz adres startu i mety, albo klikaj bezpośrednio na mapie. Punkty można przeciągać.'),
        ],
      ),
    );
  }
}

class _StopRow extends StatefulWidget {
  final Stop stop;
  final int index;
  final bool isFirst;
  final bool isLast;
  const _StopRow({super.key, required this.stop, required this.index, required this.isFirst, required this.isLast});

  @override
  State<_StopRow> createState() => _StopRowState();
}

class _StopRowState extends State<_StopRow> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  List<GeocodeResult> _results = [];
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.stop.address);
  }

  @override
  void didUpdateWidget(covariant _StopRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && _ctrl.text != widget.stop.address) {
      _ctrl.text = widget.stop.address;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _dirty = true;
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final res = await GeoService.geocode(q);
      if (mounted) setState(() => _results = res);
    });
  }

  void _pick(GeocodeResult r, PlannerController c) {
    _dirty = false;
    setState(() => _results = []);
    c.setStopLocation(widget.stop, r.latLng, address: r.main);
    _ctrl.text = r.main;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final (label, colorVal) = c.stopLabel(widget.index);
    final isEnd = widget.isFirst || widget.isLast;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 9, height: 9, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Color(colorVal), shape: BoxShape.circle)),
              Text(label.toUpperCase(),
                  style: const TextStyle(color: AppColors.inkDim, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: .8)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FieldBox(
                  controller: _ctrl,
                  hint: 'Wpisz adres lub miejsce…',
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    if (_results.isNotEmpty) _pick(_results.first, c);
                  },
                ),
              ),
              const SizedBox(width: 6),
              _SmallBtn(icon: Icons.arrow_upward, enabled: !widget.isFirst, onTap: () => c.moveStop(widget.index, -1)),
              _SmallBtn(icon: Icons.arrow_downward, enabled: !widget.isLast, onTap: () => c.moveStop(widget.index, 1)),
              _SmallBtn(
                icon: isEnd ? Icons.backspace_outlined : Icons.close,
                enabled: true,
                danger: true,
                onTap: () => c.removeStop(widget.stop.id),
              ),
            ],
          ),
          if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: AppColors.panelSolid, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  for (final r in _results)
                    InkWell(
                      onTap: () => _pick(r, c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.place, size: 14, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.main, style: const TextStyle(color: AppColors.ink, fontSize: 12.5)),
                                  if (r.rest.isNotEmpty)
                                    Text(r.rest, style: const TextStyle(color: AppColors.inkDim, fontSize: 10.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool danger;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.enabled, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
        child: IconButton(
          iconSize: 15,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: danger ? AppColors.inkDim : AppColors.inkDim),
          onPressed: enabled ? onTap : null,
        ),
      ),
    );
  }
}
