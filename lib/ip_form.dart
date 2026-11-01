// "IP settings": automatic (DHCP) or a fixed address, for Ethernet and Wi-Fi.

import 'package:flutter/material.dart';

import 'common.dart';
import 'kit/theme.dart';
import 'settings_backend.dart';

final _ipv4 = RegExp(r'^((25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(25[0-5]|2[0-4]\d|1?\d?\d)$');

/// A form for [IpConfig]; [onSave] returns null or what went wrong.
class IpForm extends StatefulWidget {
  const IpForm({super.key, required this.initial, required this.onSave});

  final IpConfig initial;
  final Future<String?> Function(IpConfig config) onSave;

  @override
  State<IpForm> createState() => _IpFormState();
}

class _IpFormState extends State<IpForm> {
  late bool _static;
  late final TextEditingController _address, _prefix, _gateway, _dns;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    final parts = c.address.split('/');
    _static = c.isStatic;
    _address = TextEditingController(text: parts.first);
    _prefix = TextEditingController(text: parts.length > 1 ? parts[1] : '24');
    _gateway = TextEditingController(text: c.gateway);
    _dns = TextEditingController(text: c.dns.join(', '));
  }

  @override
  void dispose() {
    for (final c in [_address, _prefix, _gateway, _dns]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Checks what can be checked here; the service checks again.
  String? _check(List<String> dns) {
    for (final d in dns) {
      if (!_ipv4.hasMatch(d) && !d.contains(':')) return '"$d" is not an IP address.';
    }
    if (!_static) return null;
    if (!_ipv4.hasMatch(_address.text.trim())) return 'Enter an IPv4 address, such as 192.168.1.50.';
    final prefix = int.tryParse(_prefix.text.trim());
    if (prefix == null || prefix < 1 || prefix > 32) return 'The prefix length is a number from 1 to 32 (24 is usual).';
    final gw = _gateway.text.trim();
    if (gw.isNotEmpty && !_ipv4.hasMatch(gw)) return 'The gateway must be an IPv4 address.';
    return null;
  }

  Future<void> _save() async {
    final dns = _dns.text.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).toList();
    final problem = _check(dns);
    setState(() => _error = problem);
    if (problem != null) return;
    final config = IpConfig(
      isStatic: _static,
      address: _static ? '${_address.text.trim()}/${_prefix.text.trim()}' : '',
      gateway: _static ? _gateway.text.trim() : '',
      dns: dns,
    );
    setState(() => _saving = true);
    final error = await widget.onSave(config);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error == null) showNotice(context, 'IP settings saved.', error: false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Automatic (DHCP)'), icon: Icon(Icons.autorenew_rounded)),
              ButtonSegment(value: true, label: Text('Static'), icon: Icon(Icons.push_pin_outlined)),
            ],
            selected: {_static},
            onSelectionChanged: (s) => setState(() {
              _static = s.first;
              _error = null;
            }),
            style: ButtonStyle(
              side: const WidgetStatePropertyAll(BorderSide(color: EscaColors.borderStrong)),
              foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? EscaColors.accent : EscaColors.text),
              iconColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? EscaColors.accent : EscaColors.textDim),
              backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? EscaColors.accent.withValues(alpha: 0.16) : null),
            ),
          ),
          const SizedBox(height: 20),
          if (_static) ...[
            Row(
              children: [
                Expanded(flex: 3, child: _field(_address, 'IP address', '192.168.1.50')),
                const SizedBox(width: 12),
                SizedBox(width: 120, child: _field(_prefix, 'Prefix length', '24')),
              ],
            ),
            const SizedBox(height: 14),
            _field(_gateway, 'Gateway (optional)', '192.168.1.1'),
            const SizedBox(height: 14),
          ],
          _field(_dns, _static ? 'DNS servers' : 'DNS servers (optional, instead of the network\'s)', '8.8.8.8, 1.1.1.1'),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: EscaColors.bad)),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: PillButton(label: 'Save', icon: Icons.check_rounded, primary: true, busy: _saving, onPressed: _save),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) => TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        onSubmitted: (_) => _save(),
      );
}
