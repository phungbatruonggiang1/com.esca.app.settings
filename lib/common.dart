// Pieces every settings page is built from.

import 'package:flutter/material.dart';

import 'kit/theme.dart';
import 'kit/widgets.dart';

/// A heading above a group of settings, with room for an action.
class GroupTitle extends StatelessWidget {
  const GroupTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: EscaColors.textDim, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A card holding rows, divided by hairlines.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children, this.highlight});

  final List<Widget> children;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return EscaCard(
      padding: EdgeInsets.zero,
      highlight: highlight,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: EscaColors.border, indent: 20, endIndent: 20),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One line of a group: leading icon, title and detail, trailing control.
class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EscaRadius.card),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: dense ? 12 : 16),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 16)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.titleMedium, overflow: TextOverflow.ellipsis),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: text.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
      ),
    );
  }
}

/// A label and a value, for connection details.
class DetailGrid extends StatelessWidget {
  const DetailGrid({super.key, required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = items.where((e) => e.$2.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Wrap(
        spacing: 40,
        runSpacing: 14,
        children: [
          for (final (label, value) in shown)
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.labelSmall),
                  const SizedBox(height: 4),
                  SelectableText(value, style: text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Wi-Fi strength as the familiar bars.
class SignalIcon extends StatelessWidget {
  const SignalIcon({super.key, required this.percent, this.color = EscaColors.text, this.size = 24});

  final int percent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (percent) {
      >= 75 => Icons.signal_wifi_4_bar_rounded,
      >= 50 => Icons.network_wifi_3_bar_rounded,
      >= 25 => Icons.network_wifi_2_bar_rounded,
      >= 5 => Icons.network_wifi_1_bar_rounded,
      _ => Icons.signal_wifi_0_bar_rounded,
    };
    return Icon(icon, color: color, size: size);
  }
}

/// BlueZ's icon names, as Material icons.
IconData bluetoothIcon(String icon) => switch (icon) {
      final String s when s.startsWith('audio-head') => Icons.headphones_rounded,
      final String s when s.startsWith('audio') => Icons.speaker_rounded,
      'input-keyboard' => Icons.keyboard_rounded,
      'input-mouse' || 'input-tablet' => Icons.mouse_rounded,
      'input-gaming' => Icons.sports_esports_rounded,
      'phone' => Icons.smartphone_rounded,
      'computer' => Icons.laptop_rounded,
      'camera-photo' || 'camera-video' => Icons.photo_camera_rounded,
      'printer' => Icons.print_rounded,
      final String s when s.contains('watch') => Icons.watch_rounded,
      _ => Icons.bluetooth_rounded,
    };

/// A pill-shaped secondary action.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false, this.primary = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? const Color(0xFF02201D) : EscaColors.text;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primary ? fg : EscaColors.accent))
        else if (icon != null)
          Icon(icon, size: 18),
        if (busy || icon != null) const SizedBox(width: 8),
        Text(label),
      ],
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: kEscaFontFamily, fontWeight: FontWeight.w600)),
      foregroundColor: WidgetStatePropertyAll(fg),
      side: primary ? null : const WidgetStatePropertyAll(BorderSide(color: EscaColors.borderStrong)),
      backgroundColor: WidgetStatePropertyAll(primary ? EscaColors.accent : Colors.transparent),
    );
    return primary
        ? FilledButton(onPressed: busy ? null : onPressed, style: style, child: child)
        : OutlinedButton(onPressed: busy ? null : onPressed, style: style, child: child);
  }
}

/// A short message at the bottom of the screen.
void showNotice(BuildContext context, String message, {bool error = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 560,
      backgroundColor: EscaColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: (error ? EscaColors.bad : EscaColors.good).withValues(alpha: 0.5)),
      ),
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: error ? EscaColors.bad : EscaColors.good),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(color: EscaColors.text, fontFamily: kEscaFontFamily))),
      ]),
    ));
}
