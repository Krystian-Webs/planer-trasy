import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../screens/terrain_3d_screen.dart';
import '../../services/export_service.dart';
import '../../state/planner_controller.dart';
import 'ui_kit.dart';

class Terrain3DSection extends StatelessWidget {
  const Terrain3DSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Widok 3D terenu'),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: '🌄 Pokaż trasę w 3D',
              onTap: c.lastGeometry.length < 2
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Terrain3DScreen(geometry: c.lastGeometry),
                        fullscreenDialog: true,
                      )),
            ),
          ),
          const HintText(
              'Obracana mapa z ukształtowaniem terenu i Twoją trasą. Obracasz i pochylasz dwoma palcami, a przyciskiem "Odtwórz przelot" włączysz automatyczny lot wzdłuż trasy.'),
        ],
      ),
    );
  }
}

class ExportSection extends StatelessWidget {
  const ExportSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final canExport = c.lastGeometry.length >= 2 || c.pois.isNotEmpty;
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Eksport / import'),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: '⬇ Pobierz / udostępnij plik GPX',
              primary: true,
              onTap: canExport
                  ? () => ExportService.shareGpx(projectName: c.projectName, tracks: c.tracks, pois: c.pois)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ActionButton(
              label: '⬆ Importuj plik GPX',
              onTap: () async {
                try {
                  final parsed = await ExportService.pickGpx();
                  if (parsed != null) await c.importGpx(parsed);
                } catch (_) {
                  c.toast('Nie udało się wczytać pliku GPX — sprawdź format.');
                }
              },
            ),
          ),
          const HintText(
              'GPX wczytasz do zegarka, aplikacji dla zawodników lub przekażesz służbom. Import wczytuje zapisaną trasę i punkty z pliku GPX (np. z zegarka albo Stravy).'),
        ],
      ),
    );
  }
}
