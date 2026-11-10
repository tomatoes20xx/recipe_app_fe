/// What a hand over the proximity sensor meant.
enum HandGesture {
  /// A quick pass over the sensor: next step.
  wave,

  /// The sensor covered for about a second, then cleared: previous step.
  hold,
}

/// Turns proximity readings (covered / clear) into hand gestures. A gesture
/// is decided when the sensor clears, from how long it was covered:
///
/// - up to [maxWave]: [HandGesture.wave];
/// - [minHold] to [maxHold]: [HandGesture.hold];
/// - in between: nothing, so a slow wave isn't read as a hold;
/// - longer: nothing (phone face down, leaning on something, in a pocket).
///
/// The first reading only sets the starting state, so a hand already over the
/// phone when listening starts doesn't count. After a gesture, readings within
/// [cooldown] are ignored, which absorbs a sensor flickering at the edge of
/// its range.
///
/// Pure Dart with the time passed in, so it can be tested without a device.
/// The approach follows WaveUp's detector (time how long the sensor was
/// covered and classify it on release), written from scratch here.
class HandWaveDetector {
  static const Duration maxWave = Duration(milliseconds: 800);
  static const Duration minHold = Duration(milliseconds: 1200);
  static const Duration maxHold = Duration(milliseconds: 4000);
  static const Duration cooldown = Duration(milliseconds: 600);

  bool? _near;
  Duration? _coveredAt;
  Duration? _lastGestureAt;

  /// Feeds one reading. [at] must come from a monotonic clock, e.g. a
  /// [Stopwatch]'s elapsed time. Returns the gesture this reading completes.
  HandGesture? onReading({required bool near, required Duration at}) {
    if (near == _near) return null;
    final isFirstReading = _near == null;
    _near = near;

    if (near) {
      _coveredAt = isFirstReading ? null : at;
      return null;
    }

    final coveredAt = _coveredAt;
    _coveredAt = null;
    if (coveredAt == null) return null;

    final lastGestureAt = _lastGestureAt;
    if (lastGestureAt != null && at - lastGestureAt < cooldown) return null;

    final covered = at - coveredAt;
    final HandGesture? gesture;
    if (covered <= maxWave) {
      gesture = HandGesture.wave;
    } else if (covered >= minHold && covered <= maxHold) {
      gesture = HandGesture.hold;
    } else {
      gesture = null;
    }
    if (gesture != null) _lastGestureAt = at;
    return gesture;
  }

  /// Forgets everything, e.g. after the sensor was off for a while.
  void reset() {
    _near = null;
    _coveredAt = null;
    _lastGestureAt = null;
  }
}
