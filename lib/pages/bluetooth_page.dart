import 'package:flutter/material.dart';

import '../common.dart';
import '../dialogs.dart';
import '../kit/theme.dart';
import '../kit/widgets.dart';
import '../settings_backend.dart';
import '../settings_controller.dart';
import 'empty_state.dart';

class BluetoothPage extends StatelessWidget {
  const BluetoothPage({super.key, required this.controller});

  final SettingsController controller;

  Future<void> _run(BuildContext context, Future<String?> action, {String? success}) async {
    final error = await action;
    if (!context.mounted) return;
    if (error != null) {
      showNotice(context, error);
    } else if (success != null) {
      showNotice(context, success, error: false);
    }
  }

  Future<void> _forget(BuildContext context, BluetoothDevice d) async {
    if (await confirmAction(context,
        title: 'Forget ${d.name}?', message: 'It will have to be paired again before it can connect.', action: 'Forget')) {
      if (context.mounted) await _run(context, controller.forgetDevice(d.address));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = controller.bluetooth;
    if (!b.present) {
      return const EmptyState(
          icon: Icons.bluetooth_disabled_rounded,
          title: 'No Bluetooth',
          message: 'No Bluetooth adapter is available. On a Raspberry Pi it appears a few seconds after boot.');
    }
    final paired = controller.pairedDevices;
    final available = controller.availableDevices;
    final connected = paired.where((d) => d.connected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupCard(
          highlight: connected > 0 ? EscaColors.violet.withValues(alpha: 0.5) : null,
          children: [
            SettingTile(
              leading: const IconBadge(icon: Icons.bluetooth_rounded, color: EscaColors.violet),
              title: 'Bluetooth',
              subtitle: !b.powered ? 'Off' : connected > 0 ? '$connected connected' : 'On',
              trailing: Switch(value: b.powered, onChanged: (on) => _run(context, controller.setBluetoothPowered(on))),
            ),
            if (b.powered)
              SettingTile(
                leading: const Icon(Icons.visibility_rounded, color: EscaColors.textDim),
                title: 'Visible to other devices',
                subtitle: 'Shown as "${b.name}" · ${b.address}',
                trailing: Switch(value: b.discoverable, onChanged: (on) => _run(context, controller.setDiscoverable(on))),
              ),
          ],
        ),
        if (!b.powered)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
                icon: Icons.bluetooth_disabled_rounded,
                title: 'Bluetooth is off',
                message: 'Turn it on to pair headphones, keyboards, phones and more.',
                compact: true),
          )
        else ...[
          const GroupTitle('My devices'),
          GroupCard(children: [
            if (paired.isEmpty)
              const SettingTile(
                leading: Icon(Icons.devices_other_rounded, color: EscaColors.textDim),
                title: 'No paired devices yet',
                subtitle: 'Devices you pair appear here and reconnect on their own.',
              ),
            for (final d in paired) _pairedTile(context, d),
          ]),
          GroupTitle(
            'Available devices',
            trailing: PillButton(
              label: b.discovering ? 'Stop' : 'Scan',
              icon: b.discovering ? Icons.stop_rounded : Icons.bluetooth_searching_rounded,
              onPressed: () => _run(context, controller.bluetoothScan()),
            ),
          ),
          GroupCard(children: [
            if (b.discovering) const LinearProgressIndicator(minHeight: 2, color: EscaColors.violet, backgroundColor: Colors.transparent),
            if (available.isEmpty)
              SettingTile(
                leading: const Icon(Icons.bluetooth_searching_rounded, color: EscaColors.textDim),
                title: b.discovering ? 'Looking for devices…' : 'Press Scan to look for devices',
                subtitle: 'Put the other device in pairing mode.',
              ),
            for (final d in available)
              SettingTile(
                dense: true,
                leading: IconBadge(icon: bluetoothIcon(d.icon), color: EscaColors.textDim, size: 40),
                title: d.name,
                subtitle: _strength(d.rssi),
                trailing: PillButton(
                  label: controller.busyDevices.contains(d.address) ? 'Pairing' : 'Pair',
                  busy: controller.busyDevices.contains(d.address),
                  onPressed: () => _run(context, controller.pair(d.address), success: 'Paired with ${d.name}.'),
                ),
              ),
          ]),
        ],
      ],
    );
  }

  Widget _pairedTile(BuildContext context, BluetoothDevice d) {
    final busy = controller.busyDevices.contains(d.address);
    return SettingTile(
      dense: true,
      leading: IconBadge(icon: bluetoothIcon(d.icon), color: d.connected ? EscaColors.violet : EscaColors.textDim, size: 40),
      title: d.name,
      subtitle: d.connected ? 'Connected' : 'Not connected',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        PillButton(
          label: d.connected ? 'Disconnect' : 'Connect',
          busy: busy,
          onPressed: () => _run(context, d.connected ? controller.disconnectDevice(d.address) : controller.connectDevice(d.address)),
        ),
        PopupMenuButton<void>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded, color: EscaColors.textDim),
          color: EscaColors.surfaceHigh,
          itemBuilder: (_) => [PopupMenuItem(onTap: () => _forget(context, d), child: const Text('Forget device'))],
        ),
      ]),
    );
  }

  static String _strength(int? rssi) {
    if (rssi == null) return 'Nearby';
    if (rssi >= -60) return 'Strong signal';
    if (rssi >= -75) return 'Good signal';
    return 'Weak signal';
  }
}
