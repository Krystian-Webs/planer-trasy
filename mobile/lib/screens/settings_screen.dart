import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../state/planner_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text('Ustawienia', style: TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  const _GroupLabel('Domyślne tempo'),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tempo, z jakim nowa aplikacja startuje przy szacowaniu czasu trasy.',
                          style: TextStyle(color: AppColors.inkDim, fontSize: 12.5, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in const [
                              (label: '5:00', sec: 300),
                              (label: '6:00', sec: 360),
                              (label: '7:00', sec: 420),
                              (label: '8:30 (marsz)', sec: 510),
                            ])
                              _Chip(
                                label: '${p.label} min/km',
                                selected: c.paceSec == p.sec,
                                onTap: () => c.setDefaultPaceSec(p.sec),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _GroupLabel('Dane lokalne'),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActionRow(
                          icon: Icons.history,
                          label: 'Wyczyść automatyczny zapis',
                          subtitle: 'Usuwa ostatnio otwarty projekt zapamiętany na tym urządzeniu',
                          onTap: c.clearAutosave,
                        ),
                        const Divider(color: AppColors.lineSoft, height: 20),
                        _ActionRow(
                          icon: Icons.delete_sweep_outlined,
                          danger: true,
                          label: 'Wyczyść bibliotekę tras',
                          subtitle: 'Usuwa wszystkie trasy zapisane w „Moje trasy" — nieodwracalne',
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.panelSolid,
                                title: const Text('Wyczyścić bibliotekę?', style: TextStyle(color: AppColors.ink)),
                                content: const Text('Wszystkie zapisane trasy zostaną trwale usunięte.', style: TextStyle(color: AppColors.inkDim)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń', style: TextStyle(color: AppColors.bad))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final entries = await LibraryService.list();
                              for (final e in entries) {
                                await LibraryService.delete(e.id);
                              }
                              if (context.mounted) c.toast('Wyczyszczono bibliotekę tras.');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _GroupLabel('O aplikacji'),
                  const _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Planer Trasy', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Wersja 1.0.0', style: TextStyle(color: AppColors.inkDim, fontSize: 12)),
                        SizedBox(height: 10),
                        Text(
                          'Mapy: OpenStreetMap, CARTO, Esri.\nTrasy: OSRM (routing.openstreetmap.de, project-osrm.org).\nWysokości terenu: Open-Meteo.',
                          style: TextStyle(color: AppColors.inkDim, fontSize: 11.5, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(), style: const TextStyle(color: AppColors.inkDim, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.panel,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.accent2 : AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, required this.subtitle, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Icon(icon, color: danger ? AppColors.bad : AppColors.accent2, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: danger ? AppColors.bad : AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.inkDim, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
