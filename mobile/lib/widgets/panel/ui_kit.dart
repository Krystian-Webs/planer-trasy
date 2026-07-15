import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/app_theme.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: AppColors.inkDim,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
      decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(20)),
      child: Text('$count', style: const TextStyle(color: AppColors.ink, fontSize: 10)),
    );
  }
}

class Section extends StatelessWidget {
  final Widget child;
  const Section({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 22), child: child);
  }
}

class HintText extends StatelessWidget {
  final String text;
  const HintText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Text(text, style: const TextStyle(color: AppColors.inkDim, fontSize: 11.5, height: 1.5)),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool compact;
  final double? width;
  const ActionButton({super.key, required this.label, required this.onTap, this.primary = false, this.compact = false, this.width});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: SizedBox(
        width: width,
        child: Material(
          color: primary ? null : AppColors.panel2,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              gradient: primary ? AppColors.accentGradient : null,
              border: primary ? null : Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: disabled ? null : onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 9 : 11),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primary ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FieldBox extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool dense;
  const FieldBox({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.ink, fontSize: dense ? 13 : 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5F6F80), fontSize: 13),
        filled: true,
        fillColor: AppColors.panel2,
        isDense: dense,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 9 : 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.line)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  const StatTile({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: AppColors.accent2, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.inkDim, fontSize: 9, letterSpacing: .4), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SwitchRow({super.key, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(color: AppColors.panel2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: AppColors.inkDim, fontSize: 11)),
              ],
            ),
          ),
          GlassSwitch(value: value, onChanged: onChanged, activeColor: AppColors.accent),
        ],
      ),
    );
  }
}
