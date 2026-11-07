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

enum _Credit { none, author, repository }

class _ExampleAppState extends State<ExampleApp> {
  static final Uri _repository = Uri.parse('https://github.com/alexdlaird/double_feature');

  bool _dark = false;
  _Credit _credit = _Credit.none;

  void _setDark(bool dark) => setState(() => _dark = dark);

  void _setCredit(Set<_Credit> credit) => setState(() => _credit = credit.single);

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
            ListTile(
              title: const Text('Credit'),
              trailing: SegmentedButton<_Credit>(
                segments: const [
                  ButtonSegment(value: _Credit.none, label: Text('None')),
                  ButtonSegment(value: _Credit.author, label: Text('Author')),
                  ButtonSegment(value: _Credit.repository, label: Text('GitHub')),
                ],
                selected: {_credit},
                showSelectedIcon: false,
                onSelectionChanged: _setCredit,
              ),
            ),
            Center(
              child: VersionLabel(
                version: 'v1.0.0',
                author: _credit == _Credit.author ? 'Dr. Frank-N-Furter' : null,
                repository: _credit == _Credit.repository ? _repository : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
