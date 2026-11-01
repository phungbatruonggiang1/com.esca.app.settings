// The Settings screen: sections down the left, the chosen one on the right.

import 'dart:async';

import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'kit/theme.dart';
import 'kit/widgets.dart';
import 'pages/bluetooth_page.dart';
import 'pages/ethernet_page.dart';
import 'pages/wifi_page.dart';
import 'settings_backend.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller, required this.onBack});

  final SettingsController controller;
  final VoidCallback onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription<PairingRequest>? _pairing;
  bool _pairingOpen = false;

  SettingsController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _pairing = c.pairingRequests.listen(_onPairingRequest, onError: (_) {});
  }

  @override
  void dispose() {
    _pairing?.cancel();
    super.dispose();
  }

  Future<void> _onPairingRequest(PairingRequest r) async {
    if (!mounted) return;
    if (r.kind == 'cancel') {
      if (_pairingOpen) Navigator.of(context).pop();
      return;
    }
    if (_pairingOpen) Navigator.of(context).pop(); // a new question replaces the old
    _pairingOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PairingDialog(request: r, answer: (accept, value) => c.answerPairing(r, accept, value)),
    );
    _pairingOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) => EscaBackground(
          tint: EscaColors.info,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EscaTopBar(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'Network and connected devices',
                    color: EscaColors.info,
                    onBack: widget.onBack,
                  ),
                  if (!c.available) ...[
                    const SizedBox(height: 20),
                    const FaultBanner(
                      message: 'The settings service (esca-settingsd) is not running; nothing here can be changed until it is.',
                    ),
                  ],
                  const SizedBox(height: 28),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 330, child: _Sidebar(controller: c)),
                        const SizedBox(width: 32),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1240),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: KeyedSubtree(
                                    key: ValueKey(c.section),
                                    child: switch (c.section) {
                                      SettingsSection.wifi => WifiPage(controller: c),
                                      SettingsSection.ethernet => EthernetPage(controller: c),
                                      SettingsSection.bluetooth => BluetoothPage(controller: c),
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final w = c.wifi, e = c.ethernet, b = c.bluetooth;
    final wifiStatus = !w.present
        ? 'Not available'
        : !w.enabled
            ? 'Off'
            : c.joining != null
                ? 'Connecting…'
                : w.connected
                    ? w.network!.ssid
                    : 'Not connected';
    final ethStatus = !e.present
        ? 'Not available'
        : e.link.online
            ? (e.link.ipv4.isEmpty ? 'Connected' : e.link.ipv4)
            : e.link.carrier
                ? 'Getting an address…'
                : 'Cable unplugged';
    final btConnected = c.pairedDevices.where((d) => d.connected).length;
    final btStatus = !b.present
        ? 'Not available'
        : !b.powered
            ? 'Off'
            : btConnected > 0
                ? '$btConnected connected'
                : 'On';

    return ListView(
      children: [
        _NavItem(
          icon: Icons.wifi_rounded,
          color: EscaColors.info,
          title: 'Wi-Fi',
          status: wifiStatus,
          active: w.connected,
          selected: c.section == SettingsSection.wifi,
          onTap: () => c.select(SettingsSection.wifi),
        ),
        _NavItem(
          icon: Icons.settings_ethernet_rounded,
          color: EscaColors.accent,
          title: 'Ethernet',
          status: ethStatus,
          active: e.link.online,
          selected: c.section == SettingsSection.ethernet,
          onTap: () => c.select(SettingsSection.ethernet),
        ),
        _NavItem(
          icon: Icons.bluetooth_rounded,
          color: EscaColors.violet,
          title: 'Bluetooth',
          status: btStatus,
          active: btConnected > 0,
          selected: c.section == SettingsSection.bluetooth,
          onTap: () => c.select(SettingsSection.bluetooth),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.status,
    required this.active,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String status;
  final bool active;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EscaCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        color: selected ? EscaColors.surfaceHigh : EscaColors.surface,
        highlight: selected ? color.withValues(alpha: 0.7) : null,
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (active) ...[const PulseDot(color: EscaColors.good, pulsing: false, size: 7), const SizedBox(width: 7)],
                    Expanded(child: Text(status, style: text.bodySmall, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: selected ? color : EscaColors.textFaint),
          ],
        ),
      ),
    );
  }
}
