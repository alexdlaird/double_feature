/*
 * Copyright (c) 2026 Alex Laird
 *
 * SPDX-License-Identifier: MIT
 */

import 'package:double_feature/double_feature.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  bool _dark = false;

  void _setDark(bool dark) => setState(() => _dark = dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rocky Horror Muppet Show',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            SwitchListTile(title: const Text('Dark mode'), value: _dark, onChanged: _setDark),
            const SizedBox(height: 48),
            const Center(child: VersionLabel(version: 'v1.0.0')),
          ],
        ),
      ),
    );
  }
}
