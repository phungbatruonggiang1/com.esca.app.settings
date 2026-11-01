// esca-settingsd as this application sees it: vn.sparc.esca.Settings1 on the
// system bus. State comes as JSON snapshots; signals only say "look again".

import 'dart:async';
import 'dart:convert';

import 'package:dbus/dbus.dart';

/// How an interface gets its address.
class IpConfig {
  const IpConfig({this.isStatic = false, this.address = '', this.gateway = '', this.dns = const []});

  factory IpConfig.fromJson(Map<String, dynamic> j) => IpConfig(
        isStatic: j['method'] == 'static',
        address: j['address'] as String? ?? '',
        gateway: j['gateway'] as String? ?? '',
        dns: [for (final d in (j['dns'] as List? ?? const [])) d as String],
      );

  final bool isStatic;
  final String address; // "192.168.1.50/24"
  final String gateway;
  final List<String> dns;

  Map<String, dynamic> toJson() => {
        'method': isStatic ? 'static' : 'dhcp',
        'address': address,
        'gateway': gateway,
        'dns': dns,
      };
}

/// What systemd-networkd says about an interface right now.
class LinkInfo {
  const LinkInfo({
    this.present = false,
    this.operState = '',
    this.carrier = false,
    this.mac = '',
    this.addresses = const [],
    this.gateway = '',
    this.dns = const [],
    this.speedMbps = 0,
  });

  factory LinkInfo.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const LinkInfo();
    return LinkInfo(
      present: j['present'] as bool? ?? false,
      operState: j['operState'] as String? ?? '',
      carrier: j['carrier'] as bool? ?? false,
      mac: j['mac'] as String? ?? '',
      addresses: [for (final a in (j['addresses'] as List? ?? const [])) a as String],
      gateway: j['gateway'] as String? ?? '',
      dns: [for (final d in (j['dns'] as List? ?? const [])) d as String],
      speedMbps: j['speedMbps'] as int? ?? 0,
    );
  }

  final bool present;
  final String operState;
  final bool carrier;
  final String mac;
  final List<String> addresses;
  final String gateway;
  final List<String> dns;
  final int speedMbps;

  /// The IPv4 address, without its prefix, or ''.
  String get ipv4 {
    for (final a in addresses) {
      if (!a.contains(':')) return a.split('/').first;
    }
    return '';
  }

  bool get online => operState == 'routable' || operState == 'degraded';
}

class AccessPoint {
  const AccessPoint({
    required this.ssid,
    this.bssid = '',
    this.signal = 0,
    this.band = '',
    this.security = 'open',
    this.saved = false,
    this.connected = false,
  });

  factory AccessPoint.fromJson(Map<String, dynamic> j) => AccessPoint(
        ssid: j['ssid'] as String? ?? '',
        bssid: j['bssid'] as String? ?? '',
        signal: j['signal'] as int? ?? 0,
        band: j['band'] as String? ?? '',
        security: j['security'] as String? ?? 'open',
        saved: j['saved'] as bool? ?? false,
        connected: j['connected'] as bool? ?? false,
      );

  final String ssid;
  final String bssid;

  /// 0..100.
  final int signal;
  final String band;

  /// open, wep, wpa2, wpa3, wpa2/wpa3, enterprise
  final String security;
  final bool saved;
  final bool connected;

  bool get secured => security != 'open';

  String get securityLabel => switch (security) {
        'open' => 'Open',
        'wep' => 'WEP',
        'wpa2' => 'WPA2',
        'wpa3' => 'WPA3',
        'wpa2/wpa3' => 'WPA2/WPA3',
        'enterprise' => 'Enterprise',
        _ => security.toUpperCase(),
      };
}

class WifiState {
  const WifiState({
    this.present = false,
    this.enabled = false,
    this.state = 'disconnected',
    this.connecting = '',
    this.network,
    this.link = const LinkInfo(),
    this.ipConfig = const IpConfig(),
  });

  factory WifiState.fromJson(Map<String, dynamic> j) => WifiState(
        present: j['present'] as bool? ?? false,
        enabled: j['enabled'] as bool? ?? false,
        state: j['state'] as String? ?? 'disconnected',
        connecting: j['connecting'] as String? ?? '',
        network: j['network'] == null ? null : AccessPoint.fromJson(j['network'] as Map<String, dynamic>),
        link: LinkInfo.fromJson(j['link'] as Map<String, dynamic>?),
        ipConfig: IpConfig.fromJson(j['ipConfig'] as Map<String, dynamic>? ?? const {}),
      );

  final bool present;
  final bool enabled;

  /// disconnected, scanning, connecting, connected
  final String state;

  /// The network being joined, if any.
  final String connecting;
  final AccessPoint? network;
  final LinkInfo link;
  final IpConfig ipConfig;

  bool get connected => state == 'connected' && network != null;
}

class EthernetState {
  const EthernetState({
    this.present = false,
    this.interface = 'eth0',
    this.link = const LinkInfo(),
    this.ipConfig = const IpConfig(),
  });

  factory EthernetState.fromJson(Map<String, dynamic> j) => EthernetState(
        present: j['present'] as bool? ?? false,
        interface: j['interface'] as String? ?? 'eth0',
        link: LinkInfo.fromJson(j['link'] as Map<String, dynamic>?),
        ipConfig: IpConfig.fromJson(j['ipConfig'] as Map<String, dynamic>? ?? const {}),
      );

  final bool present;
  final String interface;
  final LinkInfo link;
  final IpConfig ipConfig;
}

class BluetoothState {
  const BluetoothState({
    this.present = false,
    this.name = '',
    this.address = '',
    this.powered = false,
    this.discoverable = false,
    this.discovering = false,
  });

  factory BluetoothState.fromJson(Map<String, dynamic> j) => BluetoothState(
        present: j['present'] as bool? ?? false,
        name: j['name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        powered: j['powered'] as bool? ?? false,
        discoverable: j['discoverable'] as bool? ?? false,
        discovering: j['discovering'] as bool? ?? false,
      );

  final bool present;
  final String name;
  final String address;
  final bool powered;
  final bool discoverable;
  final bool discovering;
}

class BluetoothDevice {
  const BluetoothDevice({
    required this.address,
    required this.name,
    this.named = true,
    this.icon = '',
    this.paired = false,
    this.connected = false,
    this.rssi,
  });

  factory BluetoothDevice.fromJson(Map<String, dynamic> j) => BluetoothDevice(
        address: j['address'] as String? ?? '',
        name: j['name'] as String? ?? '',
        named: j['named'] as bool? ?? false,
        icon: j['icon'] as String? ?? '',
        paired: j['paired'] as bool? ?? false,
        connected: j['connected'] as bool? ?? false,
        rssi: j['rssi'] as int?,
      );

  final String address;
  final String name;

  /// False for a device that never told its name: BlueZ shows its address.
  final bool named;

  /// BlueZ's icon name: audio-headset, input-keyboard, phone...
  final String icon;
  final bool paired;
  final bool connected;
  final int? rssi;
}

/// BlueZ asking, through esca-settingsd, about a pairing in progress.
class PairingRequest {
  const PairingRequest({required this.address, required this.name, required this.kind, required this.value});

  factory PairingRequest.fromJson(Map<String, dynamic> j) => PairingRequest(
        address: j['address'] as String? ?? '',
        name: j['name'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        value: j['value'] as String? ?? '',
      );

  final String address;
  final String name;

  /// confirm (does [value] match?), pin, passkey (type one),
  /// display-pin / display-passkey (type [value] on the device), cancel.
  final String kind;
  final String value;
}

/// A failure the service named: WrongPassword, Timeout, InvalidArgument,
/// Unavailable, Busy, Rejected, Failed...
class SettingsError implements Exception {
  const SettingsError(this.name, this.message);

  final String name;
  final String message;

  @override
  String toString() => message.isEmpty ? name : message;
}

abstract interface class SettingsBackend {
  Future<WifiState> wifiState();
  Future<List<AccessPoint>> wifiNetworks();
  Future<void> wifiSetEnabled(bool on);
  Future<void> wifiScan();

  /// Completes once joined; throws [SettingsError] otherwise.
  Future<void> wifiConnect(String ssid, String passphrase, {bool hidden = false});
  Future<void> wifiDisconnect();
  Future<void> wifiForget(String ssid);
  Future<void> wifiSetIpConfig(IpConfig config);

  Future<EthernetState> ethernetState();
  Future<void> ethernetSetIpConfig(IpConfig config);

  Future<BluetoothState> bluetoothState();
  Future<List<BluetoothDevice>> bluetoothDevices();
  Future<void> bluetoothSetPowered(bool on);
  Future<void> bluetoothSetDiscoverable(bool on);
  Future<void> bluetoothStartDiscovery();
  Future<void> bluetoothStopDiscovery();
  Future<void> bluetoothPair(String address);
  Future<void> bluetoothConnect(String address);
  Future<void> bluetoothDisconnect(String address);
  Future<void> bluetoothRemove(String address);
  Future<void> bluetoothAnswer(String address, bool accept, String value);

  Stream<void> get wifiChanged;
  Stream<void> get wifiNetworksChanged;
  Stream<void> get ethernetChanged;
  Stream<void> get bluetoothChanged;
  Stream<void> get bluetoothDevicesChanged;
  Stream<PairingRequest> get pairingRequests;

  Future<void> dispose();
}

class DBusSettingsBackend implements SettingsBackend {
  DBusSettingsBackend() : _client = DBusClient.system() {
    _object = DBusRemoteObject(_client, name: _name, path: DBusObjectPath('/vn/sparc/esca/Settings1'));
  }

  static const _name = 'vn.sparc.esca.Settings1';
  static const _wifi = 'vn.sparc.esca.Settings1.Wifi';
  static const _ethernet = 'vn.sparc.esca.Settings1.Ethernet';
  static const _bluetooth = 'vn.sparc.esca.Settings1.Bluetooth';
  static const _errorPrefix = 'vn.sparc.esca.Settings1.Error.';

  // The system bus, explicitly: under Weston DBUS_SESSION_BUS_ADDRESS is
  // set and would otherwise win.
  final DBusClient _client;
  late final DBusRemoteObject _object;

  Future<List<DBusValue>> _call(String interface, String method, [List<DBusValue> args = const []]) async {
    try {
      final reply = await _object.callMethod(interface, method, args);
      return reply.values;
    } on DBusMethodResponseException catch (e) {
      final name = e.errorName.startsWith(_errorPrefix) ? e.errorName.substring(_errorPrefix.length) : 'Unavailable';
      final values = e.response.values;
      throw SettingsError(name, values.isNotEmpty ? values.first.asString() : e.errorName);
    }
  }

  Future<dynamic> _json(String interface, String method) async =>
      jsonDecode((await _call(interface, method)).first.asString());

  Stream<void> _signal(String interface, String name) =>
      DBusRemoteObjectSignalStream(object: _object, interface: interface, name: name).map((_) {});

  @override
  Future<WifiState> wifiState() async => WifiState.fromJson(await _json(_wifi, 'GetState') as Map<String, dynamic>);

  @override
  Future<List<AccessPoint>> wifiNetworks() async =>
      [for (final n in await _json(_wifi, 'GetNetworks') as List) AccessPoint.fromJson(n as Map<String, dynamic>)];

  @override
  Future<void> wifiSetEnabled(bool on) => _call(_wifi, 'SetEnabled', [DBusBoolean(on)]);

  @override
  Future<void> wifiScan() => _call(_wifi, 'Scan');

  @override
  Future<void> wifiConnect(String ssid, String passphrase, {bool hidden = false}) =>
      _call(_wifi, 'Connect', [DBusString(ssid), DBusString(passphrase), DBusBoolean(hidden)]);

  @override
  Future<void> wifiDisconnect() => _call(_wifi, 'Disconnect');

  @override
  Future<void> wifiForget(String ssid) => _call(_wifi, 'Forget', [DBusString(ssid)]);

  @override
  Future<void> wifiSetIpConfig(IpConfig config) =>
      _call(_wifi, 'SetIpConfig', [DBusString(jsonEncode(config.toJson()))]);

  @override
  Future<EthernetState> ethernetState() async =>
      EthernetState.fromJson(await _json(_ethernet, 'GetState') as Map<String, dynamic>);

  @override
  Future<void> ethernetSetIpConfig(IpConfig config) =>
      _call(_ethernet, 'SetIpConfig', [DBusString(jsonEncode(config.toJson()))]);

  @override
  Future<BluetoothState> bluetoothState() async =>
      BluetoothState.fromJson(await _json(_bluetooth, 'GetState') as Map<String, dynamic>);

  @override
  Future<List<BluetoothDevice>> bluetoothDevices() async => [
        for (final d in await _json(_bluetooth, 'GetDevices') as List)
          BluetoothDevice.fromJson(d as Map<String, dynamic>)
      ];

  @override
  Future<void> bluetoothSetPowered(bool on) => _call(_bluetooth, 'SetPowered', [DBusBoolean(on)]);

  @override
  Future<void> bluetoothSetDiscoverable(bool on) => _call(_bluetooth, 'SetDiscoverable', [DBusBoolean(on)]);

  @override
  Future<void> bluetoothStartDiscovery() => _call(_bluetooth, 'StartDiscovery');

  @override
  Future<void> bluetoothStopDiscovery() => _call(_bluetooth, 'StopDiscovery');

  @override
  Future<void> bluetoothPair(String address) => _call(_bluetooth, 'Pair', [DBusString(address)]);

  @override
  Future<void> bluetoothConnect(String address) => _call(_bluetooth, 'Connect', [DBusString(address)]);

  @override
  Future<void> bluetoothDisconnect(String address) => _call(_bluetooth, 'Disconnect', [DBusString(address)]);

  @override
  Future<void> bluetoothRemove(String address) => _call(_bluetooth, 'Remove', [DBusString(address)]);

  @override
  Future<void> bluetoothAnswer(String address, bool accept, String value) =>
      _call(_bluetooth, 'AnswerPairing', [DBusString(address), DBusBoolean(accept), DBusString(value)]);

  @override
  Stream<void> get wifiChanged => _signal(_wifi, 'Changed');

  @override
  Stream<void> get wifiNetworksChanged => _signal(_wifi, 'NetworksChanged');

  @override
  Stream<void> get ethernetChanged => _signal(_ethernet, 'Changed');

  @override
  Stream<void> get bluetoothChanged => _signal(_bluetooth, 'Changed');

  @override
  Stream<void> get bluetoothDevicesChanged => _signal(_bluetooth, 'DevicesChanged');

  @override
  Stream<PairingRequest> get pairingRequests =>
      DBusRemoteObjectSignalStream(object: _object, interface: _bluetooth, name: 'PairingRequest')
          .map((s) => PairingRequest.fromJson(jsonDecode(s.values.first.asString()) as Map<String, dynamic>));

  @override
  Future<void> dispose() => _client.close();
}
