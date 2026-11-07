/*
 * Copyright (c) 2026 Alex Laird
 *
 * SPDX-License-Identifier: MIT
 */

import 'package:double_feature/double_feature.dart';
import 'package:double_feature/src/version_label.dart' show debugArmRehearsal;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _version = 'v1.2.3';
const _credit = 'App by Kermit';
const _sourceLink = 'Open Source on GitHub';
final _githubUrl = Uri.parse('https://github.com/example/app');

class _FakeLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  _FakeLauncher({this.fails = false, this.opens = true});

  final bool fails;
  final bool opens;
  final List<(String, PreferredLaunchMode)> opened = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (fails) {
      throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    }
    opened.add((url, options.mode));
    return opens;
  }
}

void main() {
  Future<void> pumpLabel(
    WidgetTester tester, {
    ThemeData? theme,
    String? author,
    Uri? githubUrl,
    bool divider = true,
    VoidCallback? onGithubUrlError,
    double spacing = VersionLabel.defaultSpacing,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: VersionLabel(
              version: _version,
              author: author,
              githubUrl: githubUrl,
              onGithubUrlError: onGithubUrlError,
              divider: divider,
              spacing: spacing,
            ),
          ),
        ),
      ),
    );
  }

  Finder divider() => find.descendant(of: find.byType(VersionLabel), matching: find.byType(Divider));

  double inkInset(WidgetTester tester, String text) {
    final lineHeight = tester.getSize(find.text(text)).height;
    final fontSize = DefaultTextStyle.of(tester.element(find.text(text))).style.fontSize!;
    return (lineHeight - 0.7 * fontSize) / 2;
  }

  double inkTop(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy + inkInset(tester, text);

  double inkBottom(WidgetTester tester, String text) =>
      tester.getBottomLeft(find.text(text)).dy - inkInset(tester, text);

  double gapBetween(WidgetTester tester, String upper, String lower) =>
      inkTop(tester, lower) - inkBottom(tester, upper);

  double lineToVersion(WidgetTester tester) => inkTop(tester, _version) - tester.getBottomLeft(divider()).dy;

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

  testWidgets('test_without_author_or_github_url_shows_only_the_version', (tester) async {
    // WHEN
    await pumpLabel(tester);

    // THEN
    expect(find.textContaining('App by'), findsNothing);
    expect(find.text(_sourceLink), findsNothing);
    expect(find.text(_version), findsOneWidget);
  });

  testWidgets('test_author_adds_a_credit_row_spaced_like_the_version', (tester) async {
    // WHEN
    await pumpLabel(tester, author: 'Kermit');

    // THEN
    expect(find.text(_credit), findsOneWidget);
    expect(gapBetween(tester, _version, _credit), moreOrLessEquals(VersionLabel.defaultSpacing, epsilon: 0.5));
  });

  testWidgets('test_github_url_adds_a_link_row_that_opens_it', (tester) async {
    // GIVEN
    final launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    await pumpLabel(tester, githubUrl: _githubUrl);

    // WHEN
    await tester.tap(find.text(_sourceLink));
    await tester.pump();

    // THEN
    expect(launcher.opened, [
      (_githubUrl.toString(), PreferredLaunchMode.platformDefault),
    ], reason: "the platform's usual way for a web link");
    expect(
      gapBetween(tester, _version, _sourceLink),
      moreOrLessEquals(VersionLabel.defaultSpacing, epsilon: 0.5),
      reason: 'spaced like the credit row',
    );
  });

  testWidgets('test_tapping_the_version_row_above_the_text_counts', (tester) async {
    // GIVEN
    await pumpLabel(tester, author: 'Kermit');
    final above = tester.getTopLeft(find.text(_version)) + const Offset(2, -8);

    // WHEN
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(above);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // THEN
    expect(playing(), findsWidgets, reason: 'the whole row takes the taps, not just the text');
  });

  testWidgets('test_tapping_the_credit_does_not_count_toward_the_show', (tester) async {
    // GIVEN
    await pumpLabel(tester, author: 'Kermit');

    // WHEN
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(_credit));
      await tester.pump(const Duration(milliseconds: 100));
    }

    // THEN
    expect(playing(), findsNothing);
  });

  testWidgets('test_a_short_divider_sits_above_the_version', (tester) async {
    // WHEN
    await pumpLabel(tester, author: 'Kermit');

    // THEN
    expect(divider(), findsOneWidget);
    expect(
      tester.getBottomLeft(divider()).dy,
      lessThan(tester.getTopLeft(find.text(_version)).dy),
      reason: 'above the version',
    );
    expect(
      tester.getSize(divider()).width,
      lessThan(tester.getSize(find.byType(Scaffold)).width / 2),
      reason: 'a short rule, not a full-width line',
    );
  });

  testWidgets('test_spacing_is_the_same_above_the_line_below_it_and_between_the_rows', (tester) async {
    // WHEN
    await pumpLabel(tester, author: 'Kermit');

    // THEN
    final aboveLine = tester.getTopLeft(divider()).dy - tester.getTopLeft(find.byType(VersionLabel)).dy;
    expect(aboveLine, VersionLabel.defaultSpacing);
    expect(lineToVersion(tester), moreOrLessEquals(aboveLine, epsilon: 0.5), reason: 'line to version');
    expect(
      gapBetween(tester, _version, _credit),
      moreOrLessEquals(aboveLine, epsilon: 0.5),
      reason: 'version to credit',
    );
  });

  testWidgets('test_the_divider_can_be_turned_off', (tester) async {
    // WHEN
    await pumpLabel(tester, author: 'Kermit', divider: false);

    // THEN
    expect(divider(), findsNothing);
    expect(find.text(_version), findsOneWidget);
    expect(
      inkTop(tester, _version) - tester.getTopLeft(find.byType(VersionLabel)).dy,
      moreOrLessEquals(VersionLabel.defaultSpacing / 2, epsilon: 0.5),
      reason: 'the version row keeps its own half of the spacing',
    );
  });

  testWidgets('test_a_passed_spacing_sets_every_gap', (tester) async {
    // WHEN
    await pumpLabel(tester, author: 'Kermit', spacing: 40);

    // THEN
    expect(tester.getTopLeft(divider()).dy - tester.getTopLeft(find.byType(VersionLabel)).dy, 40);
    expect(lineToVersion(tester), moreOrLessEquals(40, epsilon: 0.5));
    expect(gapBetween(tester, _version, _credit), moreOrLessEquals(40, epsilon: 0.5));
  });

  testWidgets('test_a_link_that_will_not_open_is_ignored', (tester) async {
    // GIVEN
    UrlLauncherPlatform.instance = _FakeLauncher(fails: true);
    await pumpLabel(tester, githubUrl: _githubUrl);

    // WHEN
    await tester.tap(find.text(_sourceLink));
    await tester.pump();

    // THEN
    expect(tester.takeException(), isNull);
    expect(find.text(_sourceLink), findsOneWidget);
  });

  testWidgets('test_a_link_that_will_not_open_calls_on_github_url_error', (tester) async {
    for (final launcher in [_FakeLauncher(fails: true), _FakeLauncher(opens: false)]) {
      // GIVEN
      UrlLauncherPlatform.instance = launcher;
      var errors = 0;
      await pumpLabel(tester, githubUrl: _githubUrl, onGithubUrlError: () => errors++);

      // WHEN
      await tester.tap(find.text(_sourceLink));
      await tester.pump();

      // THEN
      expect(errors, 1, reason: 'thrown or refused, the app hears about it once');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_a_link_that_opens_does_not_call_on_github_url_error', (tester) async {
    // GIVEN
    UrlLauncherPlatform.instance = _FakeLauncher();
    var errors = 0;
    await pumpLabel(tester, githubUrl: _githubUrl, onGithubUrlError: () => errors++);

    // WHEN
    await tester.tap(find.text(_sourceLink));
    await tester.pump();

    // THEN
    expect(errors, 0);
  });
}
