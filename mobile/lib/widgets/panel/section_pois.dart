import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/planner_models.dart';
import '../../services/geo_service.dart';
import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import '../poi_type_sheet.dart';
import 'ui_kit.dart';

class PoiTypeChipsSection extends StatelessWidget {
  const PoiTypeChipsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Stawiaj punkty na mapie'),
          const Padding(
            padding: EdgeInsets.only(bottom: 9),
            child: Text('Wybierz typ, potem kliknij na mapie lub użyj wyszukiwarki u góry.',
                style: TextStyle(color: AppColors.inkDim, fontSize: 11.5, height: 1.5)),
          ),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final k in kPoiKinds)
                _PoiChip(
                  kind: k,
                  selected: c.poiType == k.key && c.mode == PlannerMode.poi,
                  onTap: () => c.setPoiType(k.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoiChip extends StatelessWidget {
  final PoiKind kind;
  final bool selected;
  final VoidCallback onTap;
  const _PoiChip({required this.kind, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.panel2,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(kind.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(kind.label,
                style: TextStyle(
                  color: selected ? AppColors.accent2 : AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

class PoiListSection extends StatelessWidget {
  const PoiListSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final byType = <String, List<Poi>>{};
    for (final p in c.pois) {
      byType.putIfAbsent(p.type, () => []).add(p);
    }
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Punkty na trasie', trailing: CountBadge(c.pois.length)),
          if (c.pois.isEmpty)
            const Text('Brak punktów. Wybierz typ powyżej i kliknij na mapie, albo rozmieść automatycznie.',
                style: TextStyle(color: AppColors.inkDim, fontSize: 12, fontStyle: FontStyle.italic)),
          for (final k in kPoiKinds)
            if (byType[k.key]?.isNotEmpty ?? false) _PoiGroup(kind: k, items: byType[k.key]!),
          if (c.pois.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ActionButton(label: 'Usuń wszystkie punkty', onTap: c.clearPois)),
          ],
        ],
      ),
    );
  }
}

class _PoiGroup extends StatelessWidget {
  final PoiKind kind;
  final List<Poi> items;
  const _PoiGroup({required this.kind, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final sorted = [...items]..sort((a, b) => (kmAlong(c.lastGeometry, a.latLng) ?? 1e9).compareTo(kmAlong(c.lastGeometry, b.latLng) ?? 1e9));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          padding: const EdgeInsets.only(bottom: 5, left: 8),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: kind.color, width: 4), bottom: const BorderSide(color: AppColors.lineSoft))),
          child: Row(
            children: [
              Text(kind.icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 7),
              Expanded(child: Text(kind.label, style: const TextStyle(color: Color(0xFFCDD6DF), fontWeight: FontWeight.w600, fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: kind.color, borderRadius: BorderRadius.circular(10)),
                child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
        ),
        for (final p in sorted) _PoiListItem(poi: p, kind: kind),
      ],
    );
  }
}

class _PoiListItem extends StatelessWidget {
  final Poi poi;
  final PoiKind kind;
  const _PoiListItem({required this.poi, required this.kind});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final km = kmAlong(c.lastGeometry, poi.latLng);
    final def = kind.label + (poi.type == 'checkpoint' && poi.checkpointNo != null ? ' ${poi.checkpointNo}' : '');
    final display = poi.name.isNotEmpty ? poi.name : def;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showPoiEditSheet(context, controller: c, poi: poi),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              Text(kind.icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 9),
              Expanded(child: Text(display, style: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Text(km != null ? '${fmtKm(km)} km' : '—', style: const TextStyle(color: AppColors.accent2, fontSize: 10.5, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => c.removePoi(poi.id),
                child: const Icon(Icons.close, size: 16, color: AppColors.inkDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
