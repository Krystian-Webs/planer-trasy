import 'package:flutter/material.dart';

/// The four sections of the tool panel — shared between the fixed
/// [BottomNavBar] and the draggable sheet's content so both stay in sync.
enum PanelTab { route, points, analysis, project }

class PanelTabInfo {
  final PanelTab tab;
  final IconData icon;
  final String label;
  const PanelTabInfo(this.tab, this.icon, this.label);
}

const kPanelTabs = [
  PanelTabInfo(PanelTab.route, Icons.route_outlined, 'Trasa'),
  PanelTabInfo(PanelTab.points, Icons.place_outlined, 'Punkty'),
  PanelTabInfo(PanelTab.analysis, Icons.insights_outlined, 'Analiza'),
  PanelTabInfo(PanelTab.project, Icons.folder_outlined, 'Projekt'),
];
