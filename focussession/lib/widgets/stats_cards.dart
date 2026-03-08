import 'package:flutter/material.dart';

class StatsSummaryCard extends StatelessWidget {
  const StatsSummaryCard({
    super.key,
    required this.title,
    required this.primary,
    required this.secondary,
    required this.icon,
  });

  final String title;
  final String primary;
  final String secondary;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: c.surfaceContainerHighest.withValues(alpha: 0.75),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: c.primary.withValues(alpha: 0.14),
              child: Icon(icon, color: c.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(primary, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    secondary,
                    style: Theme.of(context).textTheme.bodySmall,
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
