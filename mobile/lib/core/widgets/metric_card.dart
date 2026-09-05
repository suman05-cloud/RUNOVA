import 'package:flutter/material.dart';
import 'package:runova/core/theme/runova_theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = RunovaColors.primary,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: RunovaColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

