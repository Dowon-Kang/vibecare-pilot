import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A Material 3 surface for one task, with a consistent heading and spacing.
class JourneySection extends StatelessWidget {
  const JourneySection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.emphasized = false,
    this.surface,
    this.accent,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool emphasized;
  final Color? surface, accent;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: EdgeInsets.zero,
    color: surface ?? (emphasized ? AppColors.brandSoft : AppColors.canvas),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdBorder,
      side: BorderSide(
        color: emphasized ? const Color(0xFFB6DAD1) : AppColors.hairlineSoft,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      accent ??
                      (emphasized ? AppColors.brand : AppColors.brandSoft),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: accent != null || emphasized
                      ? Colors.white
                      : AppColors.brand,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}

class SettingSummary extends StatelessWidget {
  const SettingSummary({super.key, required this.values});
  final List<({String label, String value})> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(16) > 23;
      final tiles = [
        for (final item in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: AppRadius.smBorder,
              border: Border.all(color: AppColors.hairlineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ];
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  tiles[i],
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
    },
  );
}
