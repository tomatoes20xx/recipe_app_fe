import "dart:io" show Platform;

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// The phone's proximity sensor (the one that blanks the screen during
/// calls), read through `ProximityChannel.kt`. Android only for now: on
/// iPhone, watching the sensor makes iOS turn the screen off while it is
/// covered, so a wave would blink the screen.
class ProximitySensor {
  const ProximitySensor._();

  static const MethodChannel _methods = MethodChannel("yummy/proximity");
  static const EventChannel _events = EventChannel("yummy/proximity/events");

  static Future<bool> isAvailable() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _methods.invokeMethod<bool>("isAvailable") ?? false;
    } catch (_) {
      return false;
    }
  }

  /// true when something covers the sensor, false when it clears. Changes
  /// only, starting with the current state. The sensor runs only while this
  /// stream has a listener.
  static Stream<bool> get changes => _events.receiveBroadcastStream().map((event) => event == true);
}
