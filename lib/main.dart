import 'package:flutter/material.dart';

import 'kit/theme.dart';
import 'kit/widgets.dart';
import 'settings_backend.dart';
import 'settings_controller.dart';
import 'settings_screen.dart';

void main() {
  runApp(SettingsApp(controller: SettingsController(DBusSettingsBackend())));
}

class SettingsApp extends StatelessWidget {
  const SettingsApp({super.key, required this.controller, this.onBack = closeApplication});

  final SettingsController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings',
      debugShowCheckedModeBanner: false,
      theme: escaTheme(),
      home: SettingsScreen(controller: controller, onBack: onBack),
    );
  }
}
