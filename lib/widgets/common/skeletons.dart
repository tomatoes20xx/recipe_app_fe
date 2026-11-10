import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/scheduler.dart";

import "../../theme/app_tokens.dart";

// Loading placeholders ("bones"). Every bone looks the same: the
// [AppTokens.skeleton] tone with rounded corners, and a soft
// [AppTokens.skeletonShine] band sweeping diagonally across the screen.
// The band is placed in screen coordinates and timed by one app-wide clock,
// so every bone on screen catches the same wave, whichever widget drew it.
// Bones fade in over their first 250ms, so a load that finishes quickly
// doesn't flash them. With the system's "remove animations" setting on, bones
// are still.
//
// Shape skeletons like the content they stand in for (same card, radius and
// line heights), and draw static labels (section titles) as real text.

/// How long the band takes to cross the screen.
const _sweep = Duration(milliseconds: 1500);

/// One sweep plus the rest before the next.
const _period = Duration(milliseconds: 2100);

const _fadeIn = Duration(milliseconds: 250);

/// Half the width of the band, in logical pixels.
const _bandHalfWidth = 140.0;

/// The band travels right and slightly down (about 20°), so a row lights up a
/// moment after the row above it.
const _bandAngle = 0.35;

final Stopwatch _clock = Stopwatch()..start();

/// A rectangular bone. [radius] defaults to fully round for text-line bones
/// (up to 24px tall) and 12 for blocks.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, required this.height, this.radius});

  final double width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? (height <= 24 ? height / 2 : 12);
    return SizedBox(
      width: width,
      height: height,
      child: SkeletonBone(borderRadius: BorderRadius.circular(r)),
    );
  }
}

/// A round bone, for avatars.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: const SkeletonBone(circle: true));
  }
}

/// A bone that fills its parent (or takes no space when the parent is
/// unbounded): the building block of [SkeletonBox] and [SkeletonCircle], and
/// the placeholder of photos still downloading.
class SkeletonBone extends StatefulWidget {
  const SkeletonBone({super.key, this.borderRadius = BorderRadius.zero, this.circle = false});

  final BorderRadius borderRadius;
  final bool circle;

  @override
  State<SkeletonBone> createState() => _SkeletonBoneState();
}

class _SkeletonBoneState extends State<SkeletonBone> with SingleTickerProviderStateMixin {
  final _frame = _BoneFrame();
  Ticker? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _ticker?.stop();
      _frame.hold();
    } else {
      _frame.moving = true;
      final ticker = _ticker ??= createTicker(_frame.tick);
      if (!ticker.isActive) ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return _BonePaint(
      frame: _frame,
      color: t.skeleton,
      shine: t.skeletonShine,
      borderRadius: widget.borderRadius,
      circle: widget.circle,
      screen: MediaQuery.maybeSizeOf(context) ?? const Size(400, 800),
    );
  }
}

/// Repaints its bone every frame while the bone is on screen.
class _BoneFrame extends ChangeNotifier {
  /// Fade-in progress, 0 to 1.
  double appear = 0;

  /// False while animations are turned off: no band, no fade.
  bool moving = true;

  void tick(Duration elapsed) {
    appear = Curves.easeOut.transform(math.min(1.0, elapsed.inMicroseconds / _fadeIn.inMicroseconds));
    notifyListeners();
  }

  void hold() {
    appear = 1;
    moving = false;
    notifyListeners();
  }
}

class _BonePaint extends LeafRenderObjectWidget {
  const _BonePaint({
    required this.frame,
    required this.color,
    required this.shine,
    required this.borderRadius,
    required this.circle,
    required this.screen,
  });

  final _BoneFrame frame;
  final Color color;
  final Color shine;
  final BorderRadius borderRadius;
  final bool circle;
  final Size screen;

  @override
  _RenderBone createRenderObject(BuildContext context) => _RenderBone(
        frame: frame,
        color: color,
        shine: shine,
        borderRadius: borderRadius,
        circle: circle,
        screen: screen,
      );

  @override
  void updateRenderObject(BuildContext context, _RenderBone renderObject) {
    renderObject
      ..color = color
      ..shine = shine
      ..borderRadius = borderRadius
      ..circle = circle
      ..screen = screen;
  }
}

class _RenderBone extends RenderBox {
  _RenderBone({
    required _BoneFrame frame,
    required Color color,
    required Color shine,
    required BorderRadius borderRadius,
    required bool circle,
    required Size screen,
  })  : _frame = frame,
        _color = color,
        _shine = shine,
        _borderRadius = borderRadius,
        _circle = circle,
        _screen = screen;

  final _BoneFrame _frame;

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  Color _shine;
  set shine(Color value) {
    if (value == _shine) return;
    _shine = value;
    markNeedsPaint();
  }

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  bool _circle;
  set circle(bool value) {
    if (value == _circle) return;
    _circle = value;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        constraints.hasBoundedHeight ? constraints.maxHeight : 0,
      ));

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _frame.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _frame.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final appear = _frame.appear;
    if (size.isEmpty || appear <= 0) return;

    final base = _color.withValues(alpha: _color.a * appear);
    final paint = Paint()..color = base;
    if (_frame.moving) {
      final band = _band(offset, base, _shine.withValues(alpha: _shine.a * appear));
      if (band != null) paint.shader = band;
    }

    final rect = offset & size;
    if (_circle) {
      context.canvas.drawOval(rect, paint);
    } else {
      context.canvas.drawRRect(_borderRadius.toRRect(rect), paint);
    }
  }

  /// The band at this moment, laid out across the screen and mapped into this
  /// bone's canvas. Null while the band rests between sweeps.
  Shader? _band(Offset offset, Color base, Color shine) {
    final progress = (_clock.elapsedMicroseconds % _period.inMicroseconds) / _sweep.inMicroseconds;
    if (progress >= 1) return null;
    final toLocal = Matrix4.tryInvert(getTransformTo(null));
    if (toLocal == null) return null;

    // Position along the travel direction: from just before the screen's
    // top-left corner to just past its bottom-right one.
    final direction = Offset(math.cos(_bandAngle), math.sin(_bandAngle));
    final travel = _screen.width * direction.dx + _screen.height * direction.dy;
    final center = -_bandHalfWidth + (travel + 2 * _bandHalfWidth) * Curves.easeInOutSine.transform(progress);

    Offset at(double along) => MatrixUtils.transformPoint(toLocal, direction * along) + offset;
    return ui.Gradient.linear(
      at(center - _bandHalfWidth),
      at(center + _bandHalfWidth),
      [base, shine, base],
      const [0, 0.5, 1],
    );
  }
}

/// First-load placeholder for a 2-column grid of [RecipeGridTile]s: a 132px
/// photo and a title line per tile, 12px column gap, 16px row gap.
/// Not scrollable; put it inside the screen's own scroll view.
class RecipeGridSkeleton extends StatelessWidget {
  const RecipeGridSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget tile(double titleWidth) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: double.infinity, height: 132, radius: 16),
            const SizedBox(height: 10),
            SkeletonBox(width: titleWidth, height: 12),
          ],
        );

    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < rows - 1 ? 16 : 0),
            child: Row(
              children: [
                Expanded(child: tile(i.isEven ? 120 : 96)),
                const SizedBox(width: 12),
                Expanded(child: tile(i.isEven ? 84 : 112)),
              ],
            ),
          ),
      ],
    );
  }
}

/// First-load placeholder for a list of rows with a round avatar and two
/// lines of text (users, notifications, shopping items).
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.count = 6, this.leadingSize = 48, this.padding});

  final int count;
  final double leadingSize;
  final EdgeInsetsGeometry? padding;

  static const _titleWidths = [150.0, 118.0, 168.0, 132.0];
  static const _subtitleWidths = [96.0, 136.0, 80.0, 112.0];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SkeletonCircle(size: leadingSize),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: _titleWidths[i % _titleWidths.length], height: 12),
                        const SizedBox(height: 10),
                        SkeletonBox(width: _subtitleWidths[i % _subtitleWidths.length], height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// First-load placeholder for recipe result cards (Search, pantry search):
/// a `card` with a `line` border, a 64px photo, two title lines and a meta
/// line, like the real rows.
class RecipeRowSkeleton extends StatelessWidget {
  const RecipeRowSkeleton({super.key, this.count = 6, this.gap = 8, this.padding});

  final int count;

  /// Space between cards.
  final double gap;
  final EdgeInsetsGeometry? padding;

  static const _titleWidths = [0.9, 0.75, 0.85, 0.7];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: EdgeInsets.only(bottom: gap),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: radius,
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  const SkeletonBox(width: 64, height: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: w * _titleWidths[i % _titleWidths.length], height: 12),
                            const SizedBox(height: 8),
                            SkeletonBox(width: w * 0.45, height: 12),
                            const SizedBox(height: 12),
                            SkeletonBox(width: w * 0.55, height: 10),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
