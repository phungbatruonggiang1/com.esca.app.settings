// The questions Settings asks: a Wi-Fi password, a hidden network's name,
// and what a Bluetooth device needs to pair.

import 'package:flutter/material.dart';

import 'common.dart';
import 'kit/theme.dart';
import 'kit/widgets.dart';
import 'settings_backend.dart';

/// The frame of every dialog here.
class EscaDialog extends StatelessWidget {
  const EscaDialog({super.key, required this.icon, required this.title, required this.child, this.color = EscaColors.accent});

  final IconData icon;
  final String title;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EscaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EscaRadius.card),
        side: const BorderSide(color: EscaColors.borderStrong),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconBadge(icon: icon, color: color, size: 44),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              ]),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a password (and, for a hidden network, its name), then joins
/// through [join], staying open with the reason if that fails.
class WifiJoinDialog extends StatefulWidget {
  const WifiJoinDialog({super.key, this.network, required this.join});

  /// null: a hidden network, typed by name.
  final AccessPoint? network;
  final Future<String?> Function(String ssid, String passphrase, bool hidden) join;

  @override
  State<WifiJoinDialog> createState() => _WifiJoinDialogState();
}

class _WifiJoinDialogState extends State<WifiJoinDialog> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  bool get _hidden => widget.network == null;
  bool get _needsPassword => _hidden || widget.network!.secured;

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ssid = _hidden ? _ssid.text.trim() : widget.network!.ssid;
    if (ssid.isEmpty) {
      setState(() => _error = 'Enter the network name.');
      return;
    }
    final security = widget.network?.security;
    if (security != null && security != 'open' && security != 'wep' && _password.text.length < 8) {
      setState(() => _error = 'The password is at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.join(ssid, _password.text, _hidden);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = widget.network;
    return EscaDialog(
      icon: Icons.wifi_rounded,
      color: EscaColors.info,
      title: _hidden ? 'Hidden network' : n!.ssid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n != null)
            Text('${n.securityLabel} · ${n.band} · signal ${n.signal}%', style: text.bodySmall),
          if (_hidden) ...[
            TextField(
              controller: _ssid,
              autofocus: true,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Network name (SSID)', border: OutlineInputBorder()),
            ),
          ],
          if (_needsPassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              autofocus: !_hidden,
              enabled: !_busy,
              obscureText: !_show,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: _hidden ? 'Password (empty for an open network)' : 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.error_outline_rounded, color: EscaColors.bad, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: EscaColors.bad))),
            ]),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              const SizedBox(width: 12),
              PillButton(label: _busy ? 'Connecting' : 'Connect', primary: true, busy: _busy, onPressed: _submit),
            ],
          ),
        ],
      ),
    );
  }
}

/// What a device asks to pair: confirm a code, type a PIN, or show one.
class PairingDialog extends StatefulWidget {
  const PairingDialog({super.key, required this.request, required this.answer});

  final PairingRequest request;
  final Future<void> Function(bool accept, String value) answer;

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _reply(bool accept) {
    widget.answer(accept, _value.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final text = Theme.of(context).textTheme;
    final name = r.name.isEmpty ? r.address : r.name;
    final asks = r.kind == 'confirm' || r.kind == 'pin' || r.kind == 'passkey';
    Widget code(String v) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(v,
                style: text.displaySmall?.copyWith(
                    letterSpacing: 8, color: EscaColors.accent, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        );

    return EscaDialog(
      icon: Icons.bluetooth_searching_rounded,
      color: EscaColors.violet,
      title: 'Pair with $name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (r.kind) {
            'confirm' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Make sure this code is shown on $name:', style: text.bodyMedium),
                code(r.value),
              ]),
            'display-pin' || 'display-passkey' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Type this code on $name, then press Enter on it:', style: text.bodyMedium),
                code(r.value),
              ]),
            _ => TextField(
                controller: _value,
                autofocus: true,
                keyboardType: r.kind == 'passkey' ? TextInputType.number : TextInputType.text,
                onSubmitted: (_) => _reply(true),
                decoration: InputDecoration(
                  labelText: r.kind == 'passkey' ? 'Passkey shown on $name' : 'PIN for $name (often 0000 or 1234)',
                  border: const OutlineInputBorder(),
                ),
              ),
          },
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: asks
                ? [
                    TextButton(onPressed: () => _reply(false), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    PillButton(label: 'Pair', primary: true, onPressed: () => _reply(true)),
                  ]
                : [PillButton(label: 'OK', onPressed: () => Navigator.of(context).pop())],
          ),
        ],
      ),
    );
  }
}

/// "Forget HomeWiFi?" and the like.
Future<bool> confirmAction(BuildContext context,
    {required String title, required String message, required String action, IconData icon = Icons.delete_outline_rounded}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => EscaDialog(
      icon: icon,
      color: EscaColors.bad,
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EscaColors.bad, foregroundColor: Colors.white, shape: const StadiumBorder()),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ]),
      ]),
    ),
  );
  return ok ?? false;
}
