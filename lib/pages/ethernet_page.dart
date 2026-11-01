import 'package:flutter/material.dart';

import '../common.dart';
import '../ip_form.dart';
import '../kit/theme.dart';
import '../kit/widgets.dart';
import '../settings_controller.dart';
import 'empty_state.dart';

class EthernetPage extends StatelessWidget {
  const EthernetPage({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final e = controller.ethernet;
    if (!e.present) {
      return const EmptyState(
          icon: Icons.settings_ethernet_rounded, title: 'No Ethernet', message: 'This board has no wired network port.');
    }
    final l = e.link;
    final (label, color, subtitle) = l.online
        ? ('Connected', EscaColors.good, l.speedMbps > 0 ? 'Connected at ${_speed(l.speedMbps)}' : 'Connected')
        : l.carrier
            ? ('Waiting', EscaColors.warn, 'Cable connected, getting an address…')
            : ('Unplugged', EscaColors.textDim, 'Plug in a network cable');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupCard(
          highlight: l.online ? EscaColors.accent.withValues(alpha: 0.5) : null,
          children: [
            SettingTile(
              leading: const IconBadge(icon: Icons.settings_ethernet_rounded, color: EscaColors.accent),
              title: 'Ethernet (${e.interface})',
              subtitle: subtitle,
              trailing: StatusPill(label: label, color: color, live: l.carrier && !l.online),
            ),
            DetailGrid(items: [
              ('IP address', l.ipv4),
              ('Gateway', l.gateway),
              ('DNS', l.dns.join(', ')),
              ('Speed', l.speedMbps > 0 ? _speed(l.speedMbps) : ''),
              ('MAC address', l.mac),
              ('Address from', e.ipConfig.isStatic ? 'Static' : 'DHCP'),
            ]),
          ],
        ),
        const GroupTitle('IP settings'),
        GroupCard(children: [
          IpForm(
            key: ValueKey('eth-${e.ipConfig.toJson()}'),
            initial: e.ipConfig,
            onSave: controller.setEthernetIp,
          ),
        ]),
      ],
    );
  }

  static String _speed(int mbps) => mbps >= 1000 ? '${mbps ~/ 1000} Gb/s' : '$mbps Mb/s';
}
