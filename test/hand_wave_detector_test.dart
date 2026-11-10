import "package:flutter_test/flutter_test.dart";
import "package:recipe_app_fe/recipes/hand_wave_detector.dart";

Duration ms(int value) => Duration(milliseconds: value);

void main() {
  late HandWaveDetector detector;

  /// Feeds readings as (near, time in ms) and returns the gestures produced.
  List<HandGesture> feed(List<(bool, int)> readings) => [
        for (final (near, at) in readings) ?detector.onReading(near: near, at: ms(at)),
      ];

  setUp(() => detector = HandWaveDetector());

  test("a quick pass over the sensor is a wave", () {
    expect(feed([(false, 0), (true, 1000), (false, 1300)]), [HandGesture.wave]);
  });

  test("covering for about a second is a hold", () {
    expect(feed([(false, 0), (true, 1000), (false, 2500)]), [HandGesture.hold]);
  });

  test("the edges of each window count", () {
    expect(feed([(false, 0), (true, 1000), (false, 1800)]), [HandGesture.wave]);
    detector.reset();
    expect(feed([(false, 0), (true, 1000), (false, 2200)]), [HandGesture.hold]);
    detector.reset();
    expect(feed([(false, 0), (true, 1000), (false, 5000)]), [HandGesture.hold]);
  });

  test("between a wave and a hold nothing happens", () {
    expect(feed([(false, 0), (true, 1000), (false, 2000)]), isEmpty);
  });

  test("covered for a long time (face down, pocket) is ignored", () {
    expect(feed([(false, 0), (true, 1000), (false, 9000)]), isEmpty);
  });

  test("a hand already over the phone when listening starts doesn't count", () {
    expect(feed([(true, 0), (false, 200)]), isEmpty);
    // The next pass counts normally.
    expect(feed([(true, 1000), (false, 1200)]), [HandGesture.wave]);
  });

  test("repeated readings don't restart the timing", () {
    expect(feed([(false, 0), (true, 1000), (true, 1500), (false, 2500)]), [HandGesture.hold]);
  });

  test("flicker right after a gesture is ignored", () {
    expect(
      feed([(false, 0), (true, 1000), (false, 1200), (true, 1250), (false, 1300)]),
      [HandGesture.wave],
    );
  });

  test("two separate waves both count", () {
    expect(
      feed([(false, 0), (true, 1000), (false, 1200), (true, 2000), (false, 2200)]),
      [HandGesture.wave, HandGesture.wave],
    );
  });

  test("reset makes the next reading the starting state again", () {
    feed([(false, 0), (true, 1000)]);
    detector.reset();
    expect(feed([(false, 1200)]), isEmpty);
  });
}
