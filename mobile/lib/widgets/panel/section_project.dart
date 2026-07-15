import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/export_service.dart';
import '../../state/planner_controller.dart';
import 'ui_kit.dart';

class ProjectSection extends StatefulWidget {
  const ProjectSection({super.key});

  @override
  State<ProjectSection> createState() => _ProjectSectionState();
}

class _ProjectSectionState extends State<ProjectSection> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final c = context.read<PlannerController>();
    _nameCtrl = TextEditingController(text: c.projectName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    if (_nameCtrl.text != c.projectName) {
      _nameCtrl.text = c.projectName;
    }
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Projekt'),
          FieldBox(
            controller: _nameCtrl,
            hint: 'Nazwa wydarzenia',
            onChanged: (v) => c.projectName = v,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: '📤 Udostępnij projekt',
                  primary: true,
                  onTap: () => ExportService.shareProjectJson(c.serialize(), c.projectName),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionButton(
                  label: '📂 Wczytaj',
                  onTap: () async {
                    final data = await ExportService.pickProjectJson();
                    if (data != null) {
                      await c.loadProject(data);
                      c.toast('Wczytano projekt ✓');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ActionButton(
                label: '＋',
                width: 46,
                onTap: () {
                  if (c.hasContent) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Nowy projekt'),
                        content: const Text('Wyczyścić bieżący projekt?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              c.newProject();
                              _nameCtrl.text = c.projectName;
                            },
                            child: const Text('Wyczyść'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    c.newProject();
                    _nameCtrl.text = c.projectName;
                  }
                },
              ),
            ],
          ),
          const HintText(
              'Udostępnij eksportuje cały projekt (trasę, punkty, notatki) jako plik do wysłania — odbiorca otwiera go w Planerze Trasy przez „Wczytaj”.'),
        ],
      ),
    );
  }
}
