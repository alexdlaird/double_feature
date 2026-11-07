/*
 * Copyright (c) 2026 Alex Laird
 *
 * SPDX-License-Identifier: MIT
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const String muppets = 'no strings attached';

@visibleForTesting
void debugArmRehearsal() => _VersionLabelState._rehearsed = false;

/// Displays a version number.
class VersionLabel extends StatefulWidget {
  const VersionLabel({
    required this.version,
    this.style,
    this.author,
    this.repository,
    this.divider = true,
    this.spacing = defaultSpacing,
    super.key,
  }) : assert(author == null || repository == null, 'Pass an author or a repository, not both');

  /// The version to display.
  final String version;

  /// The style of the text.
  final TextStyle? style;

  /// Shown as "App by [author]".
  final String? author;

  /// Linked as "Open Source on GitHub".
  final Uri? repository;

  /// Whether a divider shows above the version.
  final bool divider;

  /// The space between each element.
  final double spacing;

  static const double defaultSpacing = 20;

  @override
  State<VersionLabel> createState() => _VersionLabelState();
}

class _VersionLabelState extends State<VersionLabel> with SingleTickerProviderStateMixin {
  static const Duration _tapWindow = Duration(milliseconds: 500);
  static const Color _textInMouth = Color(0xFFF4F1FF);
  static const double _rehearsalOpacity = 1 / 255;
  static const double _rehearsalBeatStep = 0.2;

  static const double _dividerWidth = 64;
  static const double _capHeight = 0.7;

  static bool _rehearsed = !kIsWeb;

  late final AnimationController _controller = AnimationController(vsync: this, duration: _Choreography.duration);
  Timer? _tapReset;
  int _taps = 0;
  bool _rehearsing = false;

  @override
  void dispose() {
    _tapReset?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    _rehearseOnce();
    _tapReset?.cancel();
    _taps += 1;
    if (_taps < 3) {
      _tapReset = Timer(_tapWindow, _resetTaps);
      return;
    }
    _taps = 0;
    if (!_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  void _resetTaps() => _taps = 0;

  void _rehearseOnce() {
    if (_rehearsed) {
      return;
    }
    _rehearsed = true;
    setState(() => _rehearsing = true);
    WidgetsBinding.instance.addPostFrameCallback(_endRehearsal);
  }

  void _endRehearsal(Duration _) {
    if (mounted) {
      setState(() => _rehearsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rowPadding = math.max(0.0, widget.spacing / 2 - _textInset(context));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.divider) _buildDivider(),
        _buildVersionRow(rowPadding),
        if (widget.author case final author?) _buildRow(Text('App by $author', style: widget.style), rowPadding),
        if (widget.repository case final repository?) _buildRepositoryRow(repository, rowPadding),
      ],
    );
  }

  double _textInset(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: widget.version, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final lineHeight = painter.height;
    painter.dispose();
    final capHeight = _capHeight * scaler.scale(style.fontSize ?? 14);
    return math.max(0.0, (lineHeight - capHeight) / 2);
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.only(top: widget.spacing),
      child: const SizedBox(width: _dividerWidth, child: Divider(height: 1)),
    );
  }

  Widget _buildVersionRow(double rowPadding) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: _onTap,
      child: Padding(
        padding: EdgeInsets.only(top: widget.divider ? widget.spacing / 2 : 0),
        child: _buildRow(AnimatedBuilder(animation: _controller, builder: _buildStage), rowPadding),
      ),
    );
  }

  Widget _buildRepositoryRow(Uri repository, double rowPadding) {
    return Semantics(
      link: true,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2, vertical: rowPadding),
          minimumSize: const Size(kMinInteractiveDimension, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _open(repository),
        child: Text('Open Source on GitHub', style: widget.style),
      ),
    );
  }

  Widget _buildRow(Widget child, double rowPadding) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: rowPadding),
        child: Align(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }

  Future<void> _open(Uri repository) async {
    try {
      await launchUrl(repository);
    } on PlatformException {
      return;
    }
  }

  Widget _buildStage(BuildContext context, Widget? child) {
    final playing = _controller.isAnimating;
    final pose = playing ? _Choreography.at(_controller.value * _Choreography.beats) : _Pose.still;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ..._buildPose(context, pose, mouth: playing),
        if (_rehearsing) Positioned.fill(child: _buildRehearsal(context)),
      ],
    );
  }

  Widget _buildRehearsal(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: _rehearsalOpacity,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (var beat = _rehearsalBeatStep / 2; beat < _Choreography.beats; beat += _rehearsalBeatStep)
                ..._buildPose(context, _Choreography.at(beat), mouth: true),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPose(BuildContext context, _Pose pose, {required bool mouth}) {
    final colors = Theme.of(context).colorScheme;
    final outline = colors.onSurface.withValues(alpha: 0.35);
    final shadow = colors.shadow.withValues(alpha: 0.3);

    return [
      _buildLayer(mouth ? _FeltMouthPainter(pose: pose, front: false, outline: outline, shadow: shadow) : null),
      Opacity(
        opacity: pose.textOpacity,
        child: Transform.scale(
          scale: pose.textScale,
          child: Text(widget.version, style: _textStyle(context, pose)),
        ),
      ),
      _buildLayer(mouth ? _FeltMouthPainter(pose: pose, front: true, outline: outline, shadow: shadow) : null),
    ];
  }

  TextStyle? _textStyle(BuildContext context, _Pose pose) {
    if (pose.textGlow <= 0) {
      return widget.style;
    }
    final color = widget.style?.color ?? DefaultTextStyle.of(context).style.color;
    return (widget.style ?? const TextStyle()).copyWith(color: Color.lerp(color, _textInMouth, pose.textGlow));
  }

  Widget _buildLayer(CustomPainter? painter) {
    const overhang = _FeltMouthPainter.overhang;
    return Positioned(
      left: -overhang.width,
      right: -overhang.width,
      top: -overhang.height,
      bottom: -overhang.height,
      child: IgnorePointer(child: CustomPaint(painter: painter)),
    );
  }
}

class _Pose {
  const _Pose({
    required this.beat,
    required this.scale,
    required this.side,
    required this.lift,
    required this.stretchX,
    required this.stretchY,
    required this.tilt,
    required this.openness,
    required this.textScale,
    required this.textOpacity,
    required this.textGlow,
  });

  static const _Pose still = _Pose(
    beat: -1,
    scale: 0,
    side: 0,
    lift: 0,
    stretchX: 1,
    stretchY: 1,
    tilt: 0,
    openness: 0,
    textScale: 1,
    textOpacity: 1,
    textGlow: 0,
  );

  final double beat;
  final double scale;
  final double side;
  final double lift;
  final double stretchX;
  final double stretchY;
  final double tilt;
  final double openness;
  final double textScale;
  final double textOpacity;
  final double textGlow;
}

abstract final class _Choreography {
  static const Duration beat = Duration(milliseconds: 349);
  static const double _jumpAt = 2;
  static const double _stepAt = _jumpAt + 4;
  static const int _chews = 4;
  static const double _gulpAt = _stepAt + _chews + 1;
  static const double _exitAt = _gulpAt + 1;
  static const double _returnAt = _exitAt + 1;
  static const double beats = _returnAt + 2;
  static final Duration duration = beat * beats;

  static const double _hop = 0.65;
  static const double _slide = 0.5;
  static const double _hopHeight = 26;

  static _Pose at(double t) {
    final crouch = _bump(t, _jumpAt - _hop - 0.3, _jumpAt - _hop);
    final airborne = _bump(t, _jumpAt - _hop, _jumpAt);
    final landing = _bump(t, _jumpAt, _jumpAt + 0.3);
    final stepping = _bump(t, _stepAt - _slide, _stepAt);
    final chomp = _bump(t, _stepAt, _stepAt + 0.3);
    final gulp = _bump(t, _gulpAt - 0.35, _gulpAt + 0.25);
    final cheeks = _bump(t, _stepAt, _gulpAt + 0.2);
    final chew = _chewing(t);

    return _Pose(
      beat: t,
      scale: _scale(t),
      side: _side(t),
      lift: -_hopHeight * airborne + 3 * gulp,
      stretchX: 1 + 0.1 * (crouch - airborne + landing) + 0.12 * stepping + 0.07 * cheeks + 0.04 * chew + 0.1 * gulp,
      stretchY: 1 - 0.14 * (crouch + landing) + 0.16 * airborne - 0.1 * chomp - 0.18 * gulp,
      tilt: -0.12 * airborne + _sway(t) + 0.08 * stepping,
      openness: _openness(t) + 0.3 * chew,
      textScale: _textScale(t),
      textOpacity: _textOpacity(t),
      textGlow: t < _stepAt ? _progress(t, _stepAt - 0.35, _stepAt - 0.1) : 0,
    );
  }

  static double _progress(double t, double start, double end) => ((t - start) / (end - start)).clamp(0.0, 1.0);

  static double _bump(double t, double start, double end) {
    final progress = _progress(t, start, end);
    return progress <= 0 || progress >= 1 ? 0 : math.sin(math.pi * progress);
  }

  static double _scale(double t) {
    if (t < _exitAt) {
      return Curves.easeOutBack.transform(_progress(t, 0.2, 0.95));
    }
    return 1 - Curves.easeInBack.transform(_progress(t, _exitAt, _exitAt + 1));
  }

  static double _side(double t) {
    if (t < _stepAt - _slide) {
      return 1 - 2 * Curves.easeInOut.transform(_progress(t, _jumpAt - _hop, _jumpAt));
    }
    return Curves.easeOutCubic.transform(_progress(t, _stepAt - _slide, _stepAt)) - 1;
  }

  static double _sway(double t) {
    if (t <= _jumpAt + 0.3 || t >= _stepAt - 1) {
      return 0;
    }
    return 0.035 * math.sin(math.pi * (t - _jumpAt - 0.3));
  }

  static double _openness(double t) {
    final opening = Curves.easeOut.transform(_progress(t, _stepAt - 1, _stepAt - _slide));
    final closing = Curves.easeIn.transform(_progress(t, _stepAt - 0.12, _stepAt));
    return opening * (1 - closing);
  }

  static double _chewing(double t) {
    var chew = 0.0;
    for (var i = 1; i <= _chews; i++) {
      chew += _bump(t, _stepAt + i - 0.4, _stepAt + i);
    }
    return chew;
  }

  static double _textScale(double t) {
    if (t >= _stepAt) {
      return 1;
    }
    return 1 - 0.6 * Curves.easeIn.transform(_progress(t, _stepAt - 0.3, _stepAt));
  }

  static double _textOpacity(double t) {
    if (t < _stepAt) {
      return 1;
    }
    return Curves.easeIn.transform(_progress(t, _returnAt, beats));
  }
}

class _FeltMouthPainter extends CustomPainter {
  const _FeltMouthPainter({required this.pose, required this.front, required this.outline, required this.shadow});

  final _Pose pose;
  final bool front;
  final Color outline;
  final Color shadow;

  static const Size overhang = Size(76, 38);

  static const Color _felt = Color(0xFFD7263D);
  static const Color _feltShade = Color(0xFFA51D2E);
  static const Color _feltLight = Color(0xFFF2707A);
  static const Color _throat = Color(0xFF16080B);
  static const Color _throatShade = Color(0xFF050203);
  static const Color _throatLight = Color(0xFF3A1A20);
  static const Color _tongue = Color(0xFFE5677F);
  static const Color _tongueShade = Color(0xFFB8455C);
  static const Color _tongueLight = Color(0xFFF7A1B2);
  static const Color _thread = Color(0xFFFFE3E5);
  static const double _halfWidth = 30;
  static const double _height = 26;
  static const double _clearance = 6;
  static const int _samples = 32;

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.scale <= 0.01) {
      return;
    }
    final labelHalfWidth = size.width / 2 - overhang.width;
    final reach = labelHalfWidth + _halfWidth + _clearance;
    final center = size.center(Offset.zero);

    canvas.save();
    canvas.translate(center.dx + pose.side * reach, center.dy + pose.lift);
    canvas.rotate(pose.tilt);
    canvas.scale(pose.stretchX * pose.scale, pose.stretchY * pose.scale);
    if (front) {
      _paintLips(canvas);
    } else {
      _paintInside(canvas);
    }
    canvas.restore();
  }

  double _lift(double u) => pose.openness * _height * 0.34 * (1 - u * u);

  double _drop(double u) => pose.openness * _height * 0.6 * (1 - u * u);

  double _seam(double u) => 0.05 * _height * (1 - u * u);

  double _upperOuter(double u) {
    final arch = math.pow(1 - u * u, 0.6);
    final bow = 1 - 0.3 * math.exp(-(u / 0.12) * (u / 0.12));
    return -_height / 2 * arch * bow;
  }

  double _lowerOuter(double u) => _height / 2 * math.pow(1 - u * u, 0.55);

  double _upperLipTop(double u) => _upperOuter(u) - _lift(u);

  double _upperLipBottom(double u) => _seam(u) - _lift(u);

  double _lowerLipTop(double u) => _seam(u) + _drop(u);

  double _lowerLipBottom(double u) => _lowerOuter(u) + _drop(u);

  Path _between(double Function(double) top, double Function(double) bottom) {
    final points = <Offset>[
      for (var i = 0; i <= _samples; i++) _point(i, top),
      for (var i = _samples; i >= 0; i--) _point(i, bottom),
    ];
    return Path()..addPolygon(points, true);
  }

  Offset _point(int sample, double Function(double) edge) {
    final u = 2 * sample / _samples - 1;
    return Offset(u * _halfWidth, edge(u));
  }

  void _paintInside(Canvas canvas) {
    if (pose.openness <= 0.02) {
      return;
    }
    final inside = _between(_upperLipBottom, _lowerLipTop);
    _paintFelt(canvas, inside, _throat, _throatLight, _throatShade);

    final depth = _drop(0);
    final floor = _lowerLipTop(0);
    final tongue = Path()
      ..addOval(Rect.fromCenter(center: Offset(0, floor - depth * 0.1), width: _halfWidth * 1.1, height: depth * 0.9));
    canvas.save();
    canvas.clipPath(inside);
    _paintFelt(canvas, tongue, _tongue, _tongueLight, _tongueShade);
    canvas.drawLine(
      Offset(0, floor - depth * 0.45),
      Offset(0, floor - depth * 0.15),
      Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = _tongueShade,
    );
    canvas.restore();
  }

  void _paintLips(Canvas canvas) {
    for (final lip in [_between(_lowerLipTop, _lowerLipBottom), _between(_upperLipTop, _upperLipBottom)]) {
      canvas.drawShadow(lip, shadow, 2, false);
      _paintFelt(canvas, lip, _felt, _feltLight, _feltShade);
      _paintStitches(canvas, lip);
      canvas.drawPath(
        lip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = outline,
      );
    }
  }

  void _paintFelt(Canvas canvas, Path shape, Color base, Color light, Color shade) {
    final bounds = shape.getBounds();
    canvas.drawPath(shape, Paint()..color = base);

    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light.withValues(alpha: 0.35), shade.withValues(alpha: 0.55)],
        ).createShader(bounds),
    );
    final fuzz = math.Random(7);
    final specks = (bounds.width * bounds.height / 9).round();
    for (var i = 0; i < specks; i++) {
      canvas.drawCircle(
        Offset(bounds.left + fuzz.nextDouble() * bounds.width, bounds.top + fuzz.nextDouble() * bounds.height),
        0.5 + fuzz.nextDouble() * 0.7,
        Paint()..color = (fuzz.nextBool() ? light : shade).withValues(alpha: 0.45),
      );
    }
    canvas.restore();
  }

  void _paintStitches(Canvas canvas, Path shape) {
    final center = shape.getBounds().center;
    final inset = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(0.8, 0.62, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = _thread.withValues(alpha: 0.85);
    for (final metric in shape.transform(inset.storage).computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 5.5) {
        canvas.drawPath(metric.extractPath(distance, math.min(distance + 3, metric.length)), thread);
      }
    }
  }

  @override
  bool shouldRepaint(_FeltMouthPainter oldDelegate) =>
      oldDelegate.pose.beat != pose.beat ||
      oldDelegate.front != front ||
      oldDelegate.outline != outline ||
      oldDelegate.shadow != shadow;
}
