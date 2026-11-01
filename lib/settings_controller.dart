// What the Settings screen shows and does, apart from how it looks: state
// read from esca-settingsd, refreshed whenever it says something changed,
// and the actions in progress.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'settings_backend.dart';

enum SettingsSection { wifi, ethernet, bluetooth }

class SettingsController extends ChangeNotifier {
  SettingsController(this.backend) {
    _subscriptions = [
      backend.wifiChanged.listen((_) => _refreshWifi(), onError: (_) {}),
      backend.wifiNetworksChanged.listen((_) => _refreshNetworks(scanDone: true), onError: (_) {}),
      backend.ethernetChanged.listen((_) => _refreshEthernet(), onError: (_) {}),
      backend.bluetoothChanged.listen((_) => _refreshBluetooth(), onError: (_) {}),
      backend.bluetoothDevicesChanged.listen((_) => _refreshDevices(), onError: (_) {}),
    ];
    refreshAll();
  }

  final SettingsBackend backend;
  late final List<StreamSubscription<void>> _subscriptions;
  bool _disposed = false;

  SettingsSection section = SettingsSection.wifi;

  /// False when esca-settingsd cannot be reached at all.
  bool available = true;

  WifiState wifi = const WifiState();
  List<AccessPoint> networks = const [];
  bool scanning = false;
  Timer? _scanTimeout;

  /// The network being joined from this screen.
  String? joining;

  EthernetState ethernet = const EthernetState();

  BluetoothState bluetooth = const BluetoothState();
  List<BluetoothDevice> devices = const [];

  /// Devices with an operation in progress (pairing, connecting...).
  final Set<String> busyDevices = {};

  Stream<PairingRequest> get pairingRequests => backend.pairingRequests;

  List<BluetoothDevice> get pairedDevices => devices.where((d) => d.paired).toList();

  /// Devices in range that are not paired; unnamed ones only make the list
  /// longer, so they are left out.
  List<BluetoothDevice> get availableDevices => devices.where((d) => !d.paired && d.named).toList();

  void select(SettingsSection s) {
    if (section == s) return;
    section = s;
    _notify();
    if (s == SettingsSection.wifi && wifi.enabled && networks.isEmpty) scan();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimeout?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    if (bluetooth.discovering) backend.bluetoothStopDiscovery().catchError((_) {});
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Runs a read; a failure that is not the service's own answer means the
  /// service is not there.
  Future<void> _read(Future<void> Function() f) async {
    try {
      await f();
      if (!available) {
        available = true;
      }
    } on SettingsError {
      // The service answered: it is there, just not this part.
    } catch (_) {
      available = false;
    }
    _notify();
  }

  Future<void> refreshAll() async {
    await Future.wait([_refreshWifi(), _refreshEthernet(), _refreshBluetooth(), _refreshDevices()]);
    if (wifi.enabled) {
      await _refreshNetworks();
      if (networks.isEmpty) await scan();
    }
  }

  Future<void> _refreshWifi() => _read(() async => wifi = await backend.wifiState());

  Future<void> _refreshNetworks({bool scanDone = false}) => _read(() async {
        networks = await backend.wifiNetworks();
        if (scanDone) {
          scanning = false;
          _scanTimeout?.cancel();
        }
      });

  Future<void> _refreshEthernet() => _read(() async => ethernet = await backend.ethernetState());

  Future<void> _refreshBluetooth() => _read(() async => bluetooth = await backend.bluetoothState());

  Future<void> _refreshDevices() => _read(() async => devices = await backend.bluetoothDevices());

  /// Runs an action; returns the service's explanation if it failed.
  Future<String?> _act(Future<void> Function() f) async {
    try {
      await f();
      return null;
    } on SettingsError catch (e) {
      return describe(e);
    } catch (e) {
      available = false;
      _notify();
      return 'The settings service is not running.';
    }
  }

  /// What to tell the user about a failure.
  static String describe(SettingsError e) => switch (e.name) {
        'WrongPassword' => 'Wrong password. Check it and try again.',
        'Timeout' => 'The network did not answer. Move closer or try again.',
        'Busy' => 'Another connection is in progress.',
        'Rejected' => 'The device declined the pairing.',
        _ => e.message.isEmpty ? 'Something went wrong (${e.name}).' : _sentence(e.message),
      };

  static String _sentence(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}${s.endsWith('.') ? '' : '.'}';

  // --- Wi-Fi ------------------------------------------------------------------

  Future<String?> setWifiEnabled(bool on) async {
    wifi = WifiState(
        present: wifi.present, enabled: on, state: on ? wifi.state : 'disconnected', link: wifi.link, ipConfig: wifi.ipConfig);
    if (!on) networks = const [];
    _notify();
    final error = await _act(() => backend.wifiSetEnabled(on));
    await _refreshWifi();
    return error;
  }

  Future<void> scan() async {
    if (scanning) return;
    scanning = true;
    _notify();
    // The list comes with NetworksChanged; stop the spinner regardless if
    // it never does.
    _scanTimeout?.cancel();
    _scanTimeout = Timer(const Duration(seconds: 12), () {
      scanning = false;
      _refreshNetworks();
    });
    final error = await _act(backend.wifiScan);
    if (error != null) {
      scanning = false;
      _notify();
    }
  }

  /// Joins a network; null when connected, otherwise what went wrong.
  Future<String?> join(String ssid, String passphrase, {bool hidden = false}) async {
    joining = ssid;
    _notify();
    final error = await _act(() => backend.wifiConnect(ssid, passphrase, hidden: hidden));
    joining = null;
    await Future.wait([_refreshWifi(), _refreshNetworks()]);
    return error;
  }

  Future<String?> disconnectWifi() async {
    final error = await _act(backend.wifiDisconnect);
    await _refreshWifi();
    return error;
  }

  Future<String?> forget(String ssid) async {
    final error = await _act(() => backend.wifiForget(ssid));
    await Future.wait([_refreshWifi(), _refreshNetworks()]);
    return error;
  }

  Future<String?> setWifiIp(IpConfig c) async {
    final error = await _act(() => backend.wifiSetIpConfig(c));
    await _refreshWifi();
    return error;
  }

  // --- Ethernet -----------------------------------------------------------------

  Future<String?> setEthernetIp(IpConfig c) async {
    final error = await _act(() => backend.ethernetSetIpConfig(c));
    await _refreshEthernet();
    return error;
  }

  // --- Bluetooth ------------------------------------------------------------------

  Future<String?> setBluetoothPowered(bool on) async {
    final error = await _act(() => backend.bluetoothSetPowered(on));
    await Future.wait([_refreshBluetooth(), _refreshDevices()]);
    if (on && error == null) await bluetoothScan();
    return error;
  }

  Future<String?> setDiscoverable(bool on) async {
    final error = await _act(() => backend.bluetoothSetDiscoverable(on));
    await _refreshBluetooth();
    return error;
  }

  Future<String?> bluetoothScan() async {
    final error = await _act(bluetooth.discovering ? backend.bluetoothStopDiscovery : backend.bluetoothStartDiscovery);
    await _refreshBluetooth();
    return error;
  }

  Future<String?> _onDevice(String address, Future<void> Function() f) async {
    busyDevices.add(address);
    _notify();
    final error = await _act(f);
    busyDevices.remove(address);
    await Future.wait([_refreshDevices(), _refreshBluetooth()]);
    return error;
  }

  Future<String?> pair(String address) => _onDevice(address, () => backend.bluetoothPair(address));
  Future<String?> connectDevice(String address) => _onDevice(address, () => backend.bluetoothConnect(address));
  Future<String?> disconnectDevice(String address) => _onDevice(address, () => backend.bluetoothDisconnect(address));
  Future<String?> forgetDevice(String address) => _onDevice(address, () => backend.bluetoothRemove(address));

  Future<void> answerPairing(PairingRequest r, bool accept, [String value = '']) =>
      _act(() => backend.bluetoothAnswer(r.address, accept, value.isEmpty ? r.value : value));
}
