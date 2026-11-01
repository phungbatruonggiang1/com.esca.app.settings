import 'package:flutter/material.dart';

import '../kit/theme.dart';
import '../kit/widgets.dart';

/// What a page shows when there is nothing to set: no adapter, radio off.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.compact = false});

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 24 : 80),
      child: Column(
        children: [
          IconBadge(icon: icon, color: EscaColors.textDim, size: compact ? 52 : 72),
          const SizedBox(height: 18),
          Text(title, style: text.titleLarge),
          const SizedBox(height: 8),
          Text(message, style: text.bodyMedium?.copyWith(color: EscaColors.textDim), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
