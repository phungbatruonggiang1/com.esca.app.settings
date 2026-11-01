// esca-settingsd in memory: a board with Wi-Fi, Ethernet and Bluetooth,
// for the controller tests and the screenshots.

import 'dart:async';

import 'package:esca_settings/settings_backend.dart';

class FakeSettingsBackend implements SettingsBackend {
  FakeSettingsBackend({this.reachable = true});

  bool reachable;
  final calls = <String>[];

  // Wi-Fi
  bool wifiOn = true;
  String? connectedSsid = 'ESCA-Lab';
  final passwords = <String, String>{'ESCA-Lab': 'escalab2026', 'Home 5G': 'homepassword'};
  var aps = <AccessPoint>[
    const AccessPoint(ssid: 'ESCA-Lab', bssid: 'DC:A6:32:11:22:33', signal: 86, band: '5 GHz', security: 'wpa2/wpa3', saved: true),
    const AccessPoint(ssid: 'Home 5G', bssid: 'A4:91:B1:00:00:01', signal: 64, band: '5 GHz', security: 'wpa2', saved: true),
    const AccessPoint(ssid: 'Cafe Sparc', signal: 52, band: '2.4 GHz', security: 'open'),
    const AccessPoint(ssid: 'VNPT-Tang3', signal: 38, band: '2.4 GHz', security: 'wpa2'),
    const AccessPoint(ssid: 'Office Guest', signal: 21, band: '2.4 GHz', security: 'wpa3'),
  ];
  IpConfig wifiIp = const IpConfig();

  // Ethernet
  bool cable = true;
  IpConfig ethIp = const IpConfig(isStatic: true, address: '192.168.0.101/24', gateway: '192.168.0.1', dns: ['192.168.0.1']);

  // Bluetooth
  bool btOn = true;
  bool discoverable = false;
  bool discovering = true;
  var btDevices = <BluetoothDevice>[
    const BluetoothDevice(address: '00:1B:66:AA:BB:01', name: 'Sennheiser Momentum 4', icon: 'audio-headset', paired: true, connected: true),
    const BluetoothDevice(address: '00:1B:66:AA:BB:02', name: 'Logitech K380', icon: 'input-keyboard', paired: true),
    const BluetoothDevice(address: '00:1B:66:AA:BB:03', name: 'Pixel 9', icon: 'phone', rssi: -52),
    const BluetoothDevice(address: '00:1B:66:AA:BB:04', name: 'JBL Flip 6', icon: 'audio-card', rssi: -68),
    const BluetoothDevice(address: '00:1B:66:AA:BB:05', name: 'Mi Band 8', icon: 'watch', rssi: -81),
    const BluetoothDevice(address: '00:1B:66:AA:BB:06', name: '00-1B-66-AA-BB-06', named: false, rssi: -90),
  ];

  final _wifiChanged = StreamController<void>.broadcast();
  final _networksChanged = StreamController<void>.broadcast();
  final _ethChanged = StreamController<void>.broadcast();
  final _btChanged = StreamController<void>.broadcast();
  final _devicesChanged = StreamController<void>.broadcast();
  final _pairing = StreamController<PairingRequest>.broadcast();

  void emitPairing(PairingRequest r) => _pairing.add(r);
  void finishScan() => _networksChanged.add(null);

  Future<void> _check(String call) async {
    calls.add(call);
    if (!reachable) throw StateError('no bus');
  }

  LinkInfo get _wifiLink => connectedSsid == null
      ? const LinkInfo(present: true, operState: 'no-carrier', mac: 'DC:A6:32:7E:51:0C')
      : const LinkInfo(
          present: true,
          operState: 'routable',
          carrier: true,
          mac: 'DC:A6:32:7E:51:0C',
          addresses: ['192.168.1.37/24'],
          gateway: '192.168.1.1',
          dns: ['192.168.1.1', '8.8.8.8']);

  @override
  Future<WifiState> wifiState() async {
    await _check('wifiState');
    final net = connectedSsid == null
        ? null
        : aps.firstWhere((a) => a.ssid == connectedSsid).let((a) =>
            AccessPoint(ssid: a.ssid, bssid: a.bssid, signal: a.signal, band: a.band, security: a.security, saved: true, connected: true));
    return WifiState(
        present: true,
        enabled: wifiOn,
        state: wifiOn && net != null ? 'connected' : 'disconnected',
        network: wifiOn ? net : null,
        link: _wifiLink,
        ipConfig: wifiIp);
  }

  @override
  Future<List<AccessPoint>> wifiNetworks() async {
    await _check('wifiNetworks');
    if (!wifiOn) return const [];
    return [
      for (final a in aps)
        AccessPoint(
            ssid: a.ssid,
            bssid: a.bssid,
            signal: a.signal,
            band: a.band,
            security: a.security,
            saved: a.saved,
            connected: a.ssid == connectedSsid)
    ];
  }

  @override
  Future<void> wifiSetEnabled(bool on) async {
    await _check('wifiSetEnabled($on)');
    wifiOn = on;
  }

  @override
  Future<void> wifiScan() => _check('wifiScan');

  @override
  Future<void> wifiConnect(String ssid, String passphrase, {bool hidden = false}) async {
    await _check('wifiConnect($ssid)');
    final ap = aps.where((a) => a.ssid == ssid).firstOrNull;
    if (ap == null && !hidden) throw const SettingsError('Timeout', 'no answer from the network');
    final saved = ap?.saved ?? false;
    final secured = ap?.secured ?? passphrase.isNotEmpty;
    if (secured && !(saved && passphrase.isEmpty) && passwords[ssid] != passphrase) {
      throw const SettingsError('WrongPassword', 'the password is not right');
    }
    connectedSsid = ssid;
    aps = [for (final a in aps) a.ssid == ssid ? AccessPoint(ssid: a.ssid, signal: a.signal, band: a.band, security: a.security, saved: true) : a];
  }

  @override
  Future<void> wifiDisconnect() async {
    await _check('wifiDisconnect');
    connectedSsid = null;
  }

  @override
  Future<void> wifiForget(String ssid) async {
    await _check('wifiForget($ssid)');
    if (connectedSsid == ssid) connectedSsid = null;
    aps = [for (final a in aps) a.ssid == ssid ? AccessPoint(ssid: a.ssid, signal: a.signal, band: a.band, security: a.security) : a];
  }

  @override
  Future<void> wifiSetIpConfig(IpConfig config) async {
    await _check('wifiSetIpConfig');
    wifiIp = config;
  }

  @override
  Future<EthernetState> ethernetState() async {
    await _check('ethernetState');
    return EthernetState(
      present: true,
      link: cable
          ? const LinkInfo(
              present: true,
              operState: 'routable',
              carrier: true,
              mac: 'DC:A6:32:7E:51:0B',
              addresses: ['192.168.0.101/24'],
              gateway: '192.168.0.1',
              dns: ['192.168.0.1'],
              speedMbps: 1000)
          : const LinkInfo(present: true, operState: 'no-carrier', mac: 'DC:A6:32:7E:51:0B'),
      ipConfig: ethIp,
    );
  }

  @override
  Future<void> ethernetSetIpConfig(IpConfig config) async {
    await _check('ethernetSetIpConfig');
    if (config.isStatic && !config.address.contains('/')) {
      throw const SettingsError('InvalidArgument', 'the address needs a prefix length');
    }
    ethIp = config;
  }

  @override
  Future<BluetoothState> bluetoothState() async {
    await _check('bluetoothState');
    return BluetoothState(
        present: true, name: 'esca-board', address: 'DC:A6:32:7E:51:0D', powered: btOn, discoverable: discoverable, discovering: discovering);
  }

  @override
  Future<List<BluetoothDevice>> bluetoothDevices() async {
    await _check('bluetoothDevices');
    return btOn ? btDevices : btDevices.where((d) => d.paired).toList();
  }

  @override
  Future<void> bluetoothSetPowered(bool on) async {
    await _check('bluetoothSetPowered($on)');
    btOn = on;
  }

  @override
  Future<void> bluetoothSetDiscoverable(bool on) async {
    await _check('bluetoothSetDiscoverable($on)');
    discoverable = on;
  }

  @override
  Future<void> bluetoothStartDiscovery() async {
    await _check('bluetoothStartDiscovery');
    discovering = true;
  }

  @override
  Future<void> bluetoothStopDiscovery() async {
    await _check('bluetoothStopDiscovery');
    discovering = false;
  }

  BluetoothDevice _with(BluetoothDevice d, {bool? paired, bool? connected}) => BluetoothDevice(
      address: d.address, name: d.name, named: d.named, icon: d.icon, paired: paired ?? d.paired, connected: connected ?? d.connected, rssi: d.rssi);

  void _update(String address, BluetoothDevice Function(BluetoothDevice) f) =>
      btDevices = [for (final d in btDevices) d.address == address ? f(d) : d];

  @override
  Future<void> bluetoothPair(String address) async {
    await _check('bluetoothPair($address)');
    _update(address, (d) => _with(d, paired: true, connected: true));
  }

  @override
  Future<void> bluetoothConnect(String address) async {
    await _check('bluetoothConnect($address)');
    _update(address, (d) => _with(d, connected: true));
  }

  @override
  Future<void> bluetoothDisconnect(String address) async {
    await _check('bluetoothDisconnect($address)');
    _update(address, (d) => _with(d, connected: false));
  }

  @override
  Future<void> bluetoothRemove(String address) async {
    await _check('bluetoothRemove($address)');
    btDevices = btDevices.where((d) => d.address != address).toList();
  }

  @override
  Future<void> bluetoothAnswer(String address, bool accept, String value) => _check('bluetoothAnswer($address,$accept,$value)');

  @override
  Stream<void> get wifiChanged => _wifiChanged.stream;
  @override
  Stream<void> get wifiNetworksChanged => _networksChanged.stream;
  @override
  Stream<void> get ethernetChanged => _ethChanged.stream;
  @override
  Stream<void> get bluetoothChanged => _btChanged.stream;
  @override
  Stream<void> get bluetoothDevicesChanged => _devicesChanged.stream;
  @override
  Stream<PairingRequest> get pairingRequests => _pairing.stream;

  @override
  Future<void> dispose() async {}
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
