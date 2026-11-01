import 'package:flutter/material.dart';

import '../common.dart';
import '../dialogs.dart';
import '../ip_form.dart';
import '../kit/theme.dart';
import '../kit/widgets.dart';
import '../settings_backend.dart';
import '../settings_controller.dart';
import 'empty_state.dart';

class WifiPage extends StatelessWidget {
  const WifiPage({super.key, required this.controller});

  final SettingsController controller;

  Future<void> _join(BuildContext context, AccessPoint ap) async {
    if (ap.saved || !ap.secured) {
      // Saved: wpa_supplicant has the password already.
      final error = await controller.join(ap.ssid, '');
      if (error != null && context.mounted) {
        // A saved password that no longer works: ask for the new one.
        if (error.startsWith('Wrong password') && ap.secured) {
          await _askPassword(context, ap);
        } else {
          showNotice(context, error);
        }
      }
      return;
    }
    await _askPassword(context, ap);
  }

  Future<void> _askPassword(BuildContext context, AccessPoint? ap) async {
    final joined = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WifiJoinDialog(
        network: ap,
        join: (ssid, password, hidden) => controller.join(ssid, password, hidden: hidden),
      ),
    );
    if (joined == true && context.mounted) showNotice(context, 'Connected to ${controller.wifi.network?.ssid ?? ap?.ssid ?? 'the network'}.', error: false);
  }

  Future<void> _forget(BuildContext context, String ssid) async {
    if (!await confirmAction(context,
        title: 'Forget $ssid?', message: 'The board will no longer join it on its own, and you will need the password again.', action: 'Forget')) {
      return;
    }
    final error = await controller.forget(ssid);
    if (error != null && context.mounted) showNotice(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final w = controller.wifi;
    if (!w.present) {
      return const EmptyState(icon: Icons.wifi_off_rounded, title: 'No Wi-Fi', message: 'This board has no Wi-Fi adapter, or its driver is not loaded.');
    }
    final current = w.connected ? w.network : null;
    final others = controller.networks.where((n) => !(current != null && n.ssid == current.ssid)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupCard(
          highlight: current != null ? EscaColors.info.withValues(alpha: 0.5) : null,
          children: [
            SettingTile(
              leading: const IconBadge(icon: Icons.wifi_rounded, color: EscaColors.info),
              title: 'Wi-Fi',
              subtitle: !w.enabled
                  ? 'Off'
                  : controller.joining != null
                      ? 'Connecting to ${controller.joining}…'
                      : current != null
                          ? 'Connected'
                          : 'Not connected',
              trailing: Switch(
                value: w.enabled,
                onChanged: (on) async {
                  final error = await controller.setWifiEnabled(on);
                  if (error != null && context.mounted) showNotice(context, error);
                },
              ),
            ),
            if (current != null) ...[
              SettingTile(
                leading: SignalIcon(percent: current.signal, color: EscaColors.info, size: 28),
                title: current.ssid,
                subtitle: '${current.securityLabel} · ${current.band} · signal ${current.signal}%',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const StatusPill(label: 'Connected', color: EscaColors.good, live: false),
                  const SizedBox(width: 12),
                  PillButton(
                    label: 'Disconnect',
                    onPressed: () async {
                      final error = await controller.disconnectWifi();
                      if (error != null && context.mounted) showNotice(context, error);
                    },
                  ),
                  _Menu(items: {'Forget network': () => _forget(context, current.ssid)}),
                ]),
              ),
              DetailGrid(items: [
                ('IP address', w.link.ipv4),
                ('Gateway', w.link.gateway),
                ('DNS', w.link.dns.join(', ')),
                ('Access point', current.bssid),
                ('MAC address', w.link.mac),
                ('Address from', w.ipConfig.isStatic ? 'Static' : 'DHCP'),
              ]),
            ],
          ],
        ),
        if (w.enabled) ...[
          GroupTitle(
            'Available networks',
            trailing: PillButton(
              label: controller.scanning ? 'Scanning' : 'Scan',
              icon: Icons.refresh_rounded,
              busy: controller.scanning,
              onPressed: controller.scan,
            ),
          ),
          GroupCard(children: [
            if (others.isEmpty)
              SettingTile(
                leading: const Icon(Icons.wifi_find_rounded, color: EscaColors.textDim),
                title: controller.scanning ? 'Looking for networks…' : 'No networks found',
                subtitle: controller.scanning ? null : 'Press Scan to look again.',
              ),
            for (final n in others)
              SettingTile(
                dense: true,
                leading: SignalIcon(percent: n.signal, color: n.saved ? EscaColors.info : EscaColors.text),
                title: n.ssid,
                subtitle: [if (n.saved) 'Saved', n.securityLabel, n.band].join(' · '),
                onTap: controller.joining == null ? () => _join(context, n) : null,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (controller.joining == n.ssid)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (n.secured)
                    const Icon(Icons.lock_outline_rounded, size: 18, color: EscaColors.textDim),
                  if (n.saved) _Menu(items: {'Forget network': () => _forget(context, n.ssid)}),
                ]),
              ),
            SettingTile(
              dense: true,
              leading: const Icon(Icons.add_rounded, color: EscaColors.accent),
              title: 'Add a hidden network',
              onTap: controller.joining == null ? () => _askPassword(context, null) : null,
            ),
          ]),
          const GroupTitle('IP settings'),
          GroupCard(children: [
            IpForm(
              key: ValueKey('wifi-${w.ipConfig.toJson()}'),
              initial: w.ipConfig,
              onSave: controller.setWifiIp,
            ),
          ]),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
                icon: Icons.wifi_off_rounded, title: 'Wi-Fi is off', message: 'Turn it on to see the networks around the board.', compact: true),
          ),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.items});

  final Map<String, VoidCallback> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, color: EscaColors.textDim),
      color: EscaColors.surfaceHigh,
      onSelected: (f) => f(),
      itemBuilder: (_) => [for (final e in items.entries) PopupMenuItem(value: e.value, child: Text(e.key))],
    );
  }
}
