import 'package:esca_settings/main.dart';
import 'package:esca_settings/settings_backend.dart';
import 'package:esca_settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<SettingsController> ready(FakeSettingsBackend backend) async {
  final c = SettingsController(backend);
  await c.refreshAll();
  return c;
}

void main() {
  test('reads all three sections on start', () async {
    final c = await ready(FakeSettingsBackend());
    expect(c.wifi.connected, isTrue);
    expect(c.wifi.network!.ssid, 'ESCA-Lab');
    expect(c.networks, hasLength(5));
    expect(c.ethernet.link.online, isTrue);
    expect(c.ethernet.link.ipv4, '192.168.0.101');
    expect(c.pairedDevices, hasLength(2));
    // Devices that never said their name stay out of the list.
    expect(c.availableDevices.map((d) => d.name), isNot(contains('00-1B-66-AA-BB-06')));
  });

  test('joining: a wrong password is reported, the right one connects', () async {
    final backend = FakeSettingsBackend();
    final c = await ready(backend);
    expect(await c.join('VNPT-Tang3', 'nope-nope'), startsWith('Wrong password'));
    expect(c.joining, isNull);
    backend.passwords['VNPT-Tang3'] = 'correct-horse';
    expect(await c.join('VNPT-Tang3', 'correct-horse'), isNull);
    expect(c.wifi.network!.ssid, 'VNPT-Tang3');
    expect(c.networks.firstWhere((n) => n.ssid == 'VNPT-Tang3').saved, isTrue);
  });

  test('a saved network joins without a password', () async {
    final backend = FakeSettingsBackend();
    final c = await ready(backend);
    expect(await c.join('Home 5G', ''), isNull);
    expect(c.wifi.network!.ssid, 'Home 5G');
  });

  test('the scan spinner stops when the networks arrive', () async {
    final backend = FakeSettingsBackend();
    final c = await ready(backend);
    await c.scan();
    expect(c.scanning, isTrue);
    backend.finishScan();
    await pumpEventQueue();
    expect(c.scanning, isFalse);
  });

  test('turning Wi-Fi off empties the list at once', () async {
    final c = await ready(FakeSettingsBackend());
    await c.setWifiEnabled(false);
    expect(c.wifi.enabled, isFalse);
    expect(c.networks, isEmpty);
  });

  test('a service error is told in words', () async {
    final c = await ready(FakeSettingsBackend());
    final error = await c.setEthernetIp(const IpConfig(isStatic: true, address: '10.0.0.5'));
    expect(error, 'The address needs a prefix length.');
  });

  test('no service: the screen says so instead of failing', () async {
    final c = await ready(FakeSettingsBackend(reachable: false));
    expect(c.available, isFalse);
  });

  test('pairing marks the device busy, then paired and connected', () async {
    final backend = FakeSettingsBackend();
    final c = await ready(backend);
    final future = c.pair('00:1B:66:AA:BB:03');
    expect(c.busyDevices, contains('00:1B:66:AA:BB:03'));
    expect(await future, isNull);
    expect(c.busyDevices, isEmpty);
    expect(c.pairedDevices.map((d) => d.name), contains('Pixel 9'));
  });

  testWidgets('a confirmation request opens the pairing dialog and answers it', (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    final backend = FakeSettingsBackend();
    final c = await ready(backend);
    c.select(SettingsSection.bluetooth);
    await tester.pumpWidget(SettingsApp(controller: c, onBack: () {}));
    await tester.pump();
    backend.emitPairing(const PairingRequest(address: '00:1B:66:AA:BB:03', name: 'Pixel 9', kind: 'confirm', value: '482913'));
    // Not pumpAndSettle: the discovery bar animates for as long as it scans.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('482913'), findsOneWidget);
    await tester.tap(find.text('Pair').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(backend.calls, contains('bluetoothAnswer(00:1B:66:AA:BB:03,true,482913)'));
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
