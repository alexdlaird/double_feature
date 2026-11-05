/*
 * Copyright (c) 2026 Alex Laird
 *
 * SPDX-License-Identifier: MIT
 */

import 'package:double_feature/double_feature.dart';
import 'package:double_feature/src/version_label.dart' show debugArmRehearsal;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _version = 'v1.2.3';

void main() {
  Future<void> pumpLabel(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(child: VersionLabel(version: _version)),
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, {int times = 1, Duration between = const Duration(milliseconds: 100)}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text(_version).first);
      await tester.pump(between);
    }
  }

  Finder playing() => find.descendant(
    of: find.byType(VersionLabel),
    matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter != null),
  );

  Finder rehearsal() => find.descendant(
    of: find.byType(VersionLabel),
    matching: find.byWidgetPredicate((widget) => widget is Opacity && widget.opacity == 1 / 255),
  );

  double versionOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.ancestor(of: find.text(_version), matching: find.byType(Opacity)).first).opacity;

  testWidgets('test_shows_version', (tester) async {
    // WHEN
    await pumpLabel(tester);

    // THEN
    expect(find.text(_version), findsOneWidget);
    expect(playing(), findsNothing);
  });

  testWidgets('test_two_taps_do_nothing', (tester) async {
    // GIVEN
    await pumpLabel(tester);

    // WHEN
    await tap(tester, times: 2);
    await tester.pump(const Duration(seconds: 1));

    // THEN
    expect(playing(), findsNothing);
  });

  testWidgets('test_slow_taps_do_nothing', (tester) async {
    // GIVEN
    await pumpLabel(tester);

    // WHEN
    await tap(tester, times: 3, between: const Duration(milliseconds: 600));

    // THEN
    expect(playing(), findsNothing);
  });

  testWidgets('test_three_taps_play_once', (tester) async {
    // GIVEN
    await pumpLabel(tester);

    // WHEN
    await tap(tester, times: 3);

    // THEN
    expect(playing(), findsWidgets);
    await tester.pump(const Duration(milliseconds: 5000));
    expect(playing(), findsWidgets, reason: 'still playing');
    await tester.pump(const Duration(milliseconds: 300));
    expect(playing(), findsNothing, reason: 'finished');
  });

  testWidgets('test_version_hidden_while_playing_and_restored_after', (tester) async {
    // GIVEN
    await pumpLabel(tester);

    // WHEN
    await tap(tester, times: 3);
    await tester.pump(const Duration(milliseconds: 3400));

    // THEN
    expect(versionOpacity(tester), 0, reason: 'hidden mid-way');
    await tester.pump(const Duration(milliseconds: 2300));
    expect(versionOpacity(tester), 1, reason: 'restored once finished');
  });

  testWidgets('test_taps_while_playing_do_not_restart', (tester) async {
    // GIVEN
    await pumpLabel(tester);
    await tap(tester, times: 3);
    await tester.pump(const Duration(milliseconds: 1200));

    // WHEN
    await tap(tester, times: 3);
    await tester.pump(const Duration(milliseconds: 4100));

    // THEN
    expect(playing(), findsNothing);
  });

  testWidgets('test_paints_in_light_and_dark', (tester) async {
    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      // GIVEN
      await pumpLabel(tester, theme: theme);

      // WHEN
      await tap(tester, times: 3);
      for (var elapsed = 0; elapsed <= 5400; elapsed += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // THEN
      expect(tester.takeException(), isNull);
      expect(playing(), findsNothing);
    }
  });

  testWidgets('test_first_tap_rehearses_for_one_invisible_frame', (tester) async {
    // GIVEN
    debugArmRehearsal();
    await pumpLabel(tester);

    // WHEN
    await tap(tester);

    // THEN
    expect(rehearsal(), findsOneWidget, reason: 'rehearsing on the first tap');
    expect(
      find.ancestor(of: rehearsal(), matching: find.byType(IgnorePointer)),
      findsWidgets,
      reason: 'the rehearsal cannot take taps',
    );
    expect(find.text(_version), findsWidgets);
    await tester.pump();
    expect(rehearsal(), findsNothing, reason: 'gone after one frame');
    expect(playing(), findsNothing, reason: 'a rehearsal is not a show');
    expect(find.text(_version), findsOneWidget);
  });

  testWidgets('test_rehearsal_happens_once', (tester) async {
    // GIVEN
    debugArmRehearsal();
    await pumpLabel(tester);
    await tap(tester);
    await tester.pump(const Duration(seconds: 1));

    // WHEN
    await tap(tester);

    // THEN
    expect(rehearsal(), findsNothing);
  });

  testWidgets('test_rehearsal_does_not_delay_the_show', (tester) async {
    // GIVEN
    debugArmRehearsal();
    await pumpLabel(tester);

    // WHEN
    await tap(tester, times: 3);

    // THEN
    expect(rehearsal(), findsNothing);
    expect(playing(), findsWidgets);
    await tester.pump(const Duration(milliseconds: 5300));
    expect(playing(), findsNothing, reason: 'finished');
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_rehearsal_is_hidden_from_screen_readers', (tester) async {
    // GIVEN
    final semantics = tester.ensureSemantics();
    debugArmRehearsal();
    await pumpLabel(tester);

    // WHEN
    await tap(tester);

    // THEN
    expect(rehearsal(), findsOneWidget);
    expect(find.bySemanticsLabel(_version), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('test_screen_readers_see_plain_text', (tester) async {
    // GIVEN
    final semantics = tester.ensureSemantics();

    // WHEN
    await pumpLabel(tester);

    // THEN
    expect(tester.getSemantics(find.text(_version)), isNot(matchesSemantics(hasTapAction: true)));
    semantics.dispose();
  });
}
